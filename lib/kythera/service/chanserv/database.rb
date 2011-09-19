#
# kythera: services for IRC networks
# lib/kythera/service/chanserv/database.rb: database models for chanserv
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Database
    class Account
        one_to_many :chanserv_privileges,
                    :class_name => ChannelService::Privilege
    end

    #
    # This module creates and manages channels in the database. It allows for
    # global privileges, such as allowing a user to drop any channel or issue
    # the RECOVER command for any channel, or privileges per-channel, such as
    # auto-opping or auto-voicing a user. There are also flags that can be set
    # on a channel, with values, such as mlock, or topiclock.
    #
    module ChannelService
        #
        # The prefix we use for storing any keys in an AccountField.
        #
        # @private
        #
        PREFIX = 'chanserv'

        #
        # Base exception class for any ChannelService errors. Should probably
        # not be used directly.
        #
        # @private
        #
        class Error < Exception; end

        #
        # When attempting to register a channel that already exists, this
        # exception will be thrown.
        #
        class ChannelExistsError < Error; end

        #
        # The handlers to call when a user is getting promoted from successor
        # to founder.
        #
        # @private
        #
        @@succession_handlers = []

        #
        # Registers a handler to be called for an Account which is being
        # promoted to founder from successor. This happens when all founders
        # have dropped their accounts.
        #
        # @note There is no assumption made about founders who are resigning
        #   their status, however. Hmm.
        #
        # @param [Proc] block The handler to process the succession event.
        # @example
        #   ChannelService.on_succession do |account, channel|
        #     $log.debug("#{account.login} is succeeding on #{channel.name}!")
        #   end
        #
        def self.on_succession(&block)
            @@succession_handlers << block
        end

        #
        # This is the class that drives most of the work on the database side of
        # this service.
        #
        class Channel < Sequel::Model(:chanserv_channels)
            one_to_many :privileges
            one_to_many :flags

            #
            # Registers a channel name with an initial founder (at least one
            # founder is required for a channel to exist). Raises an error if
            # the channel already exists.
            #
            # @param [Account] account The initial founder
            # @param [String] name The channel name
            # @return [Channel] The newly-registered channel
            # @raise [ChannelExistsError] If the channel name is taken
            # @example
            #   account = Account.resolve('rakaur@malkier.net')
            #   channel = Channel.register(account, '#malkier')
            #
            #   # ...
            #
            #   account = Account.resolve('sycobuny@malkier.net')
            #   channel = Channel.register(account, '#malkier') # ERROR!
            #
            def self.register(account, name)
                account = Account.resolve(account)
                channel = Channel[:name => name]
                raise ChannelExistsError if channel

                channel = Channel.new
                channel.name = name
                channel.grant(account, :founder)

                channel.save

                channel
            end

            #
            # Drops a channel and all of its related privileges. It does not
            # check any permissions before doing so.
            #
            # @note Does not raise any errors if the channel can't be resolved,
            #   but it will probably die horribly in that case instead.
            #
            # @param [Object] channel The channel to be dropped
            # @example
            #   channel = Channel.resolve('#malkier')
            #   Channel.drop(channel)
            #
            def self.drop(channel)
                channel.flags.delete
                channel.privileges.delete
                channel.delete
            end

            #
            # Resolves a channel. Currently this does not provide for extensions
            # the way Account does. That is, you can only resolve it by passing
            # an existing Channel object, an Integer representing the channel ID
            # in the database, or a String representing the channel name.
            #
            # Note, passing an Integer is the same as calling `Channel[id]`
            #
            # @note Unsure if this should raise errors on failure. Currently it
            #   simply returns nil.
            #
            # @param [Channel, Integer, String] channel The channel to resolve
            # @example
            #   channel = Channel.resolve(14)
            #   channel = Channel.resolve(channel)
            #   channel = Channel.resolve('#malkier')
            #
            def self.resolve(channel)
                return channel if channel.kind_of?(Channel)
                return Channel[channel] if channel.kind_of?(Integer)
                return Channel[:name => channel.to_s].first
            end

            #
            # Returns the value associated with a given channel flag, or nil if
            # the flag is not set.
            #
            # @param [String, #to_s] flag The flag to retrieve
            # @param [String] The value of the flag
            # @example
            #   channel = Channel.resolve('#malkier')
            #   channel[:mlock] # '+nt'
            #
            def [](flag)
                super

                flagobj = flags.where(:flag => flag.to_s).first
                flagobj && flagobj.value
            end

            #
            # Sets a flag for the channel. Values can be anything, but will be
            # converted into strings.
            #
            # @note Setting a value to `nil` will in fact set it to '', which
            #   returns true in a boolean comparison. To unset a flag, use
            #   `#delete_flag`.
            # @note The related case of setting a value to `false` will return
            #   the `String` 'false', which is also a true value.
            #
            # @note Would a special case where channel[flag] = nil unsets it be
            #   the better solution here?
            #
            # @param [String, #to_s] flag The flag to set
            # @param [String, #to_s] value The value to set to the flag.
            # @example
            #   channel = Channel.resolve('#malkier')
            #   channel[:hold] = true # make #malkier permanent
            #
            def []=(flag, value)
                super

                if (flagobj = flags[:flag => flag.to_s].first)
                    flagobj.update(:value => value.to_s)
                else
                    flags.insert(:value => value.to_s)
                end
            end

            #
            # Deletes (unsets) a flag from the channel.
            #
            # @param [String, #to_s] flag The flag to delete
            # @example
            #   channel = Channel.resolve('#malkier')
            #   channel.delete_flag(:hold) # make malkier no longer permnanent
            #
            def delete_flag(flag)
                flags[:flag => flag.to_s].delete
            end

            #
            # Lists all the flags currently set on the channel.
            #
            # @return [Array] The list of flags
            # @example
            #   channel = Channel.resolve('#malkier')
            #   channel.flag_list # ['mlock', 'topic', 'website']
            #
            def flag_list
                flags.to_a.collect { |flag| flag.flag }
            end

            #
            # Grants a privilege on a the service to a specific user, such as a
            # user to the list of people allowed to drop channels (to prevent
            # abuse or for general maintenance purposes)
            #
            # @param [Account] account The account being granted a privilege
            # @param [String, #to_s] privilege The privilege being granted
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   Channel.grant(account, :drop)
            #
            def self.grant(account, privilege)
                account["#{PREFIX}.#{privilege}"] = true
            end

            #
            # Revokes a privilege on the service from a specific user.
            #
            # @param [Account] account The account having a privilege revoked
            # @param [String, #to_s] privilege The privilege being revoked
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   Channel.revoke(account, :recover)
            #
            def self.revoke(account, privilege)
                account = Account.resolve(account)
                account.delete("#{PREFIX}.#{privilege}")
            end

            #
            # Determines whether the given user has the privilege on the
            # service.
            #
            # @param [Account] account The account being checked
            # @param [String, #to_s] privilege The privilege being checked
            # @example
            #   account = Account.resolve('sycobuny2malkier.net')
            #   Channel.has_privilege?(account, :drop) # true
            #   Channel.has_privilege?(account, :clear) # false
            #
            def self.has_privilege?(account, privilege)
                account = Account.resolve(account)
                !! account["#{PREFIX}.#{privilege}"]
            end

            #
            # Grants a privilege on a specific channel to a specific user, such
            # as adding a user to the operators list.
            #
            # @param [Object] account The account being granted a privilege
            # @param [String, #to_s] privilege The privilege being granted
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   channel = Channel.resolve('#malkier')
            #   channel.grant(account, :aop)
            #
            def grant(account, privilege)
                account = Account.resolve(account)
                fields  = {:account => account, :privilege => privilege.to_s}

                privileges.insert(fields) if privileges.where(fields).empty?
            end

            #
            # Revokes a privilege on a specific channel from a specific user.
            #
            # @param [Account] account The account having a privilege revoked
            # @param [String, #to_s] privilege The privilege being revoked
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   channel = Channel.resolve('#malkier')
            #   channel.revoke(account, :successor)
            #
            def revoke(account, privilege)
                account = Account.resolve(account)
                fields  = {:account => account, :privilege => privilege.to_s}

                privileges.where(fields).delete
            end

            #
            # Determines whether the given user has the privilege on a specific
            # channel.
            #
            # @param [Account] account The account being checked
            # @param [String, #to_s] privilege The privilege being checked
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   channel = Channel.resolve('#malkier')
            #   channel.has_privilege?(account, :aop)       # true
            #   channel.has_privilege?(account, :successor) # false
            #
            def has_privilege?(account, privilege)
                account = Account.resolve(account)
                fields  = {:account => account, :privilege => privilege.to_s}

                ! privileges.where(fields).empty?
            end
        end

        #
        # Represents the channel flags model in the database. Probably should
        # not be used directly.
        #
        # @private
        #
        class Flag < Sequel::Model(:chanserv_flags)
            many_to_one :channel
        end

        #
        # Represents the channel privileges model in the database. Probably
        # should not be used directly.
        #
        # @private
        #
        class Privilege < Sequel::Model(:chanserv_privileges)
            many_to_one :account
            many_to_one :channel
        end

        #
        # Helper for Account objects.
        #
        class Helper < Account::Helper
            #
            # This defines a method for each privilege in
            # ChannelService::PRIVILEGES so that you can perform checks on them
            # quickly.
            #
            # @return [Boolean]
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   account.cs.drop?
            #
            ::ChannelService::PRIVILEGES.each do |privilege|
                meth = "#{privilege.to_s}?".to_sym
                define_method(meth) do
                    @account["#{PREFIX}.#{privilege}"]
                end
            end

            #
            # This defines a method for each privilege in
            # ChannelService::CHANNEL_PRIVILEGES so that you can perform checks
            # on them quickly.
            #
            # @param [Channel] channel The channel to check a privilege for
            # @return [Boolean]
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   channel = Channel.resolve('#malkier')
            #   account.cs.aop?(channel)
            #
            ::ChannelService::CHANNEL_PRIVILEGES.each do |privilege|
                meth = "#{privilege.to_s}?".to_sym
                define_method(meth) do |channel|
                    channel = Channel.resolve(channel)
                    channel.has_privilege?(@account, privilege)
                end
            end

            #
            # A shortcut to granting privileges to accounts. If `channel` is
            # `nil` or left off, then it grants a global service privilege,
            # otherwise it grants a privilege on that specific channel.
            #
            # @param [String, #to_s] privilege The privilege to grant
            # @param [Channel] channel The channel to grant it to
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   channel = Channel.resolve('#malkier')
            #   account.cs.grant(:drop)
            #   account.cs.grant(:aop, channel)
            #
            def grant(privilege, channel = nil)
                if channel
                    channel = Channel.resolve(channel)
                    channel.grant(@account, privilege)
                else
                    Channel.grant(@account, privilege)
                end
            end

            #
            # A shortcut to revoking privileges to accounts. If `channel` is
            # `nil` or left off, then it revokes a global service privilege,
            # otherwise it revokes a privilege on that specific channel.
            #
            # @param [String, #to_s], privilege The privilege to revoke
            # @param [Channel] channel The channel to revoke it from
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   channel = Channel.resolve('#malkier')
            #   account.cs.revoke(:recover)
            #   account.cs.revoke(:successor, channel)
            #
            def revoke(privilege, channel = nil)
                if channel
                    channel = Channel.resolve(channel)
                    channel.revoke(@account, privilege)
                else
                    Channel.revoke(@account, privilege)
                end
            end
        end

        Account.before_drop do |account|
            ap = Privilege[:account => account]

            # find the channel ids where this account is the last founder
            lfc = ap.where(:privilege => 'founder')
            lfc = lfc.group_by(:channel_id)
            lfc = lfc.having { {count(:*) => 1} }
            ids = lfc.all.collect { |privilege| privilege.channel_id }

            # find the successors on all those channels
            where = {:channel_id => ids, :privilege => 'successor'}
            succ_privs = Privilege[where]

            # find channel ids where there are no successors
            drops = Hash(ids.zip([]).flatten)
            del = succ_privs.group_by(:channel_id)
            del = del.having { count(:*) > 0 }
            del.all.collect { |privilege| drops.delete(privilege.channel_id) }
            drops = drops.keys

            # upgrade successors to founders if the rite of succession has
            # occured on these channels, and call any handlers that have hooked
            # in to being alerted about this event
            succ_privs.update(:privilege => 'founder')
            succ_privs.eager([:channel, :account]).each do |privilege|
                @@succession_handlers.each do |handler|
                    handler.call(privilege.account, privilege.channel)
                end
            end

            # drop the channels. drop privs and flags first. don't use
            # Channel.drop() and iterate cause that could get slow.
            Privilege[:channel_id => drops].delete
            Flag[:channel_id => drops].delete
            Channel[:id => drops].delete

            # drop any remaining privileges on this account
            ap.delete
        end

        # Registers the helper to be accessible through `account.chanserv` and
        # `account.cs`
        Account.helper [:chanserv, :cs], Helper
    end
end
