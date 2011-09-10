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

    module ChannelService
        PREFIX = 'chanserv'

        class Error < Exception; end
        class ChannelExistsError < Error; end

        @@succession_handlers = []

        def self.on_succession(&block)
            @@succession_handlers << block
        end

        class Channel < Sequel::Model(:chanserv_channels)
            one_to_many :privileges
            one_to_many :flags

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

            def self.drop(channel)
                channel = Channel.resolve(channel)

                channel.flags.delete
                channel.privileges.delete
                channel.delete
            end

            def self.resolve(channel)
                return channel if channel.kind_of?(Channel)
                return Channel[channel] if channel.kind_of?(Integer)
                return Channel[:name => channel.to_s].first
            end

            def [](flag)
                flagobj = flags.where(:flag => flag.to_s).first
                flagobj && flagobj.value
            end

            def []=(flag, value)
                if (flagobj = flags[:flag => flag.to_s].first)
                    flagobj.update(:value => value.to_s)
                else
                    flags.insert(:value => value.to_s)
                end
            end

            def delete_flag(flag)
                flags[:flag => flag.to_s].delete
            end

            def flag_list
                flags.to_a.collect { |flag| flag.flag }
            end

            def self.grant(account, privilege)
                account = Account.resolve(account)
                account["#{PREFIX}.#{privilege}"] = true
            end

            def self.revoke(account, privilege)
                account = Account.resolve(account)
                account.delete("#{PREFIX}.#{privilege}")
            end

            def grant(account, privilege)
                account = Account.resolve(account)
                fields  = {:account => account, :privilege => privilege.to_s}

                privileges.insert(fields) if privileges.where(fields).empty?
            end

            def revoke(account, privilege)
                account = Account.resolve(account)
                fields  = {:account => account, :privilege => privilege.to_s}

                privileges.where(fields).delete
            end

            def has_privilege?(account, privilege)
                account = Account.resolve(account)
                fields  = {:account => account, :privilege => privilege.to_s}

                ! privileges.where(where).empty?
            end
        end

        class Flag < Sequel::Model(:chanserv_flags)
            many_to_one :channel
        end

        class Privilege < Sequel::Model(:chanserv_privileges)
            many_to_one :account
            many_to_one :channel
        end

        class Helper < Account::Helper
            ::ChannelService::PRIVILEGES.each do |privilege|
                meth = "#{privilege.to_s}?".to_sym
                define_method(meth) do
                    @account["#{PREFIX}.#{privilege}"]
                end
            end

            ::ChannelService::CHANNEL_PRIVILEGES.each do |privilege|
                meth = "#{privilege.to_s}?".to_sym
                define_method(meth) do |channel|
                    channel = Channel.resolve(channel)
                    channel.has_privilege?(@account, privilege)
                end
            end

            def grant(privilege, channel = nil)
                if channel
                    channel = Channel.resolve(channel)
                    channel.grant(@account, privilege)
                else
                    Channel.grant(@account, privilege)
                end
            end

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

        Account.helper [:chanserv, :cs], Helper
    end
end
