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
        one_to_many :chanserv_channel_founders,
                    :class_name => Database::ChanServ::Channel,
                    :foreign_key => :founder_id
        one_to_many :chanserv_channel_successors,
                    :class_name => Database::ChanServ::Channel,
                    :foreign_key => :successor_id
        one_to_many :chanserv_privileges,
                    :class_name => Database::ChanServ::Privilege
    end

    module ChanServ
        class Channel < Sequel::Model(:chanserv_channels)
            BOOL_FLAGS  = [:hold, :secure, :verbose, :neverop]
            VALUE_FLAGS = [:key, :mode_list, :topic]

            BOOL_PRIVS  = [:aop, :sop, :vop]
            VALUE_PRIVS = []

            many_to_one :founder,    :class_name => Database::Account
            many_to_one :successor,  :class_name => Database::Account
            one_to_many :privileges, :class_name => Database::ChanServ::Privilege
            one_to_many :flags,      :class_name => Database::ChanServ::Flag

            def self.register(account, name)
                account = Database::Account.resolve(account)
                channel = Channel[:name => name]
                return nil if channel

                channel = Channel.new
                channel.name = name
                channel.founder = account

                channel.save
            end

            def set_successor(account)
                account = Database::Account.resolve(account)
                update(:successor_id => account.id)
            end

            def [](flag)
                flagobj = flags.where(:flag => flag).first
                flagobj ? objectify(flagobj.value, :flag) : nil
            end

            def []=(flag, value)
                if (flagobj = flags[:flag => flag].first)
                    flagobj.update(:value => value)
                else
                    flags.insert(:value => value)
                end

                objectify(value, :flag)
            end

            def grant_privilege(account, privilege, value = nil)
                account = Database::Account.resolve(account)
                if (privobj = privileges.where(:account_id => account.id, :privilege => privilege).first)
                    privobj.update(:value => value)
                else
                    privileges.insert(:account_id => account.id, :privilege => privilege, :value => value)
                end

                objectify(value, :privilege)
            end

            def revoke_privilege(account, privilege, value = nil)
                account = Database::Account.resolve(account)
                privileges.where(:account_id => account.id, :privilege => privilege).delete
            end

            def privilege_value(account, privilege)
                account = Database::Account.resolve(account)
                privobj = privileges.where(:account_id => account.id, :privilege => privilege).first
                privobj ? objectify(privobj.value, :privilege) : nil
            end

            def has_privilege?(account, privilege)
                privilege_value(account, privilege) ? true : false
            end

            #######
            private
            #######

            def objectify(value, type)
                bool, value = (type == :flag) ? [BOOL_FLAGS, VALUE_FLAGS] : [BOOL_PRIVS, VALUE_PRIVS]
                bool.include?(type) ? (value == 'true' ? true : false) : value.to_s
            end
        end

        class Flag < Sequel::Model(:chanserv_flags)
            many_to_one :channel, :class_name => Database::ChanServ::Channel
        end

        class Privilege < Sequel::Model(:chanserv_privileges)
            many_to_one :account, :class_name => Database::Account
            many_to_one :channel, :class_name => Database::ChanServ::Channel
        end

        Database::Account.before_unregister do |account|
            Privilege.where(:account_id => account.id).delete

            Channel.where(:successor_id => account.id).update(:successor_id => nil)
            Channel.filter do
                founder_id   == account.id and
                successor_id != nil
            end.update(:founder_id => :successor_id, :successor_id => nil)
            to_delete = Channel.filter do
                founder_id   == account.id and
                successor_id == nil
            end

            ids = to_delete.collect { |channel| channel.id }
            Privilege.where(:channel_id => ids).delete
            to_delete.delete
        end
    end
end
