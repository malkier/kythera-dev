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
        SUCCESSION_HANDLERS = []

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
            SUCCESSION_HANDLERS << block
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
                assert { :account }
                channel = Channel[:name => name]
                raise ChannelExistsError if channel

                channel = Channel.new
                channel.name = name
                channel.registered    = DateTime.now
                channel.last_activity = DateTime.now
                channel.save

                channel.grant(account, :founder)
                channel
            end

            #
            # Drops a channel and all of its related privileges. It does not
            # check any permissions before doing so.
            #
            # @note Does not raise any errors if the channel can't be resolved,
            #   but it will probably die horribly in that case instead.
            #
            # @param [Channel] channel The channel to be dropped
            # @example
            #   channel = Channel.resolve('#malkier')
            #   Channel.drop(channel)
            #
            def self.drop(channel)
                assert { :channel }
                channel.flags_dataset.delete
                channel.privileges_dataset.delete
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
                return Channel.where(:name => channel.to_s).first
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
                return super if self.class.columns.include?(flag)

                flagobj = flags_dataset.filter { {:flag => flag.to_s} }.first
                flagobj && flagobj.value
            end

            #
            # Sets a flag for the channel. Values can be anything, but will be
            # converted into strings. Setting a value to 'nil' or 'false' will
            # delete the flag.
            #
            # @param [String, #to_s] flag The flag to set
            # @param [String, #to_s] value The value to set to the flag.
            # @example
            #   channel = Channel.resolve('#malkier')
            #   channel[:hold] = true # make #malkier permanent
            #
            def []=(flag, value)
                return super if self.class.columns.include?(flag)
                return delete_flag(flag) unless value

                flagobj = flags_dataset.filter { {:flag => flag.to_s} }.first
                if flagobj
                    flagobj.update(:value => value.to_s)
                else
                    require 'logger'

                    Flag.insert(
                        :channel_id => self.id,
                        :flag       => flag.to_s,
                        :value      => value.to_s
                    )
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
                flags_dataset.filter { {:flag => flag.to_s} }.delete
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
                flags.to_a.collect(&:flag)
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
                account.delete_field("#{PREFIX}.#{privilege}")
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
                fields = {
                    :account_id => account.id,
                    :privilege  => privilege.to_s
                }

                if priv = privileges_dataset.filter { fields }.first
                    return priv
                end

                fields[:channel_id] = self.id
                Privilege.insert(fields)
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
                check_succession!(account) if privilege.to_s == 'founder'

                fields  = {
                    :channel_id => self.id,
                    :account_id => account.id,
                    :privilege  => privilege.to_s
                }
                privileges_dataset.filter { fields }.delete
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
                assert { :account }
                fields  = {:account => account, :privilege => privilege.to_s}

                ! privileges_dataset.filter { fields }.to_a.empty?
            end

            #######
            private
            #######

            def check_succession!(account, skip_safety_checks = false)
                unless skip_safety_checks
                    return if privileges_dataset.filter do
                        {:account => account, :privilege => 'founder'}
                    end.empty?
                end

                found = privileges_dataset.filter { {:privilege => 'founder'} }
                succ = privileges_dataset.filter { {:privilege => 'successor'} }
                return unless found.count == 1

                if succ.count == 0
                    self.class.drop(self)
                else
                    succ.eager(:account).each do |succession|
                        SUCCESSION_HANDLERS.each do |handler|
                            handler.call(succession.account, self)
                        end
                    end
                    succ.update(:privilege => 'founder')
                end
            end

            #
            # Checks the privileges in the database when an account is dropped,
            # thus implicitly removing them as founder from any channel they
            # have the status on. See Channel#check_succession! for more
            # details.
            #
            # @private
            #
            def self.check_succession!(account)
                # privileges where this account is a founder
                ap = Privilege.filter do
                    {:account => account, :privilege => 'founder'}
                end

                # channel ids where this account is a founder
                fc = ap.select(:channel_id).collect { |r| r[:channel_id] }

                # there's nothing to do if this account is a founder nowhere
                return if fc.empty?

                # channels with only one founder left
                lfc = Privilege.filter do
                    {:channel_id => fc, :privilege => 'founder'}
                end.group_by(:channel_id).having { {count('*'.lit) => 1} }
                ids = lfc.collect { |privilege| privilege.channel_id }

                # there's nothing to do if there are no last-founder accounts
                return if ids.empty?

                # find the successors on all those channels
                where = {:channel_id => ids, :privilege => 'successor'}
                succ_privs = Privilege.filter { where }

                # set up qualifying SQL bits to find channel ids where there are
                # no successors
                my_id = :id.qualify(table_name)
                priv_opts = {my_id => :channel_id, :privilege => 'successor'}
                nosucc = ~(Privilege.filter { priv_opts }.select(1).exists)

                # find channel ids where there are no successors
                drop_ids = Channel.filter do
                    nosucc & {:id => ids}
                end.select(:id).collect(&:id)

                # upgrade successors to founders if the rite of succession has
                # occured on these channels, and call any handlers that have
                # hooked in to being alerted about this event
                succ_privs.eager([:channel, :account]).each do |privilege|
                    SUCCESSION_HANDLERS.each do |handler|
                        handler.call(privilege.account, privilege.channel)
                    end
                end
                succ_privs.update(:privilege => 'founder')

                # there are no channels to drop so we can stop here.
                return if drop_ids.empty?

                # drop the channels. drop privs and flags first. don't use
                # Channel.drop() and iterate cause that could get slow.
                Privilege.filter { {:channel_id => drop_ids} }.delete
                Flag     .filter { {:channel_id => drop_ids} }.delete
                Channel  .filter { {:id         => drop_ids} }.delete
            end

            # actually necessary in spite of "private" earlier
            private_class_method :check_succession!
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
            many_to_one :account, :class => Account
            many_to_one :channel
        end

        #
        # Helper for Account objects.
        #
        class Helper < Account::Helper
            @@first_run = true

            def initialize(*args)
                super

                return unless @@first_run
                @@first_run = false

                self.class.instance_eval do
                    #
                    # This defines a method for each privilege in
                    # ChannelService::PRIVILEGES so that you can perform
                    # checks on them quickly.
                    #
                    # @return [True, False]
                    # @example
                    #   account = Account.resolve('sycobuny@malkier.net')
                    #   account.cs.drop?
                    #
                    ::ChannelService::PRIVILEGES.each do |privilege|
                        meth = "#{privilege.to_s}?".to_sym
                        define_method(meth) do
                            !! @account["#{PREFIX}.#{privilege}"]
                        end
                    end

                    #
                    # This defines a method for each privilege in
                    # ChannelService::CHANNEL_PRIVILEGES so that you can
                    # perform checks on them quickly.
                    #
                    # @param [Channel] channel The channel to check for the priv
                    # @return [True, False]
                    # @example
                    #   account = Account.resolve('sycobuny@malkier.net')
                    #   channel = Channel.resolve('#malkier')
                    #   account.cs.aop?(channel)
                    #
                    ::ChannelService::CHANNEL_PRIVILEGES.each do |privilege|
                        meth = "#{privilege.to_s}?".to_sym
                        define_method(meth) do |channel|
                            assert { :channel }
                            channel.has_privilege?(@account, privilege)
                        end
                    end
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
                    assert { :channel }
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
                    assert { :channel }
                    channel.revoke(@account, privilege)
                else
                    Channel.revoke(@account, privilege)
                end
            end
        end

        Account.before_drop do |account|
            # this takes care of the legwork of succession, such as if this
            # account was the last of a channel's founders
            Channel.send(:check_succession!, account)

            # drop any remaining privileges on this account
            Privilege.where(:account => account).delete
        end

        # Registers the helper to be accessible through `account.chanserv` and
        # `account.cs`
        Account.helper [:chanserv, :cs], Helper
    end

    class Account
        one_to_many :chanserv_privileges,
                    :class_name => ChannelService::Privilege
    end
end
