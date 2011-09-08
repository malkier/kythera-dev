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
                    :class_name => ChanServ::Channel,
                    :foreign_key => :founder_id
        one_to_many :chanserv_channel_successors,
                    :class_name => ChanServ::Channel,
                    :foreign_key => :successor_id
        one_to_many :chanserv_privileges,
                    :class_name => ChanServ::Privilege
    end

    module ChanServ
        class Error < Exception; end
        class ChannelExistsError < Error; end

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
                raise ChannelExistsError if channel

                channel = Channel.new
                channel.name    = name
                channel.founder = account

                channel.save
            end

            def set_successor(account)
                account = Account.resolve(account)
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
                account = Account.resolve(account)
                where = {:account => account, :privilege => privilege.to_s}
                fields = where.merge(:value => value.to_s)

                if (privobj = privileges.where(where).first)
                    privobj.update(fields)
                else
                    privileges.insert(fields)
                end

                objectify(value, :privilege)
            end

            def revoke_privilege(account, privilege, value = nil)
                account = Database::Account.resolve(account)
                where   = {:account => account, :privilege => privilege.to_s}
                privileges.where(where).delete
            end

            def privilege_value(account, privilege)
                account = Account.resolve(account)
                where   = {:account => account, :privilege => privilege.to_s}

                privobj = privileges.where(where).first
                privobj ? objectify(privobj.value, :privilege) : nil
            end

            def has_privilege?(account, privilege)
                privilege_value(account, privilege) ? true : false
            end

            #######
            private
            #######

            def objectify(value, type)
                test_bool = false

                if type == :flag
                    test_bool = BOOL_FLAGS.include?(type)
                else
                    test_bool = BOOL_PRIVS.include?(type)
                end

                test_bool ? (value.to_s == 'true' ? true : false) : value.to_s
            end
        end

        class Flag < Sequel::Model(:chanserv_flags)
            many_to_one :channel, :class_name => Database::ChanServ::Channel
        end

        class Privilege < Sequel::Model(:chanserv_privileges)
            many_to_one :account, :class_name => Database::Account
            many_to_one :channel, :class_name => Database::ChanServ::Channel
        end

        Account.before_unregister do |account|
            Privilege.where(:account => account).delete

            Channel.where(:successor => account).update(:successor => nil)
            Channel.filter do |row|
                row.founder_id    == account.id and
                row.succcessor_id != nil
            end.update(:founder => :successor, :successor => nil)

            to_delete = Channel.where(:founder => account, :successor => nil)
            ids = to_delete.collect { |channel| channel.id }
            Privilege.where(:channel_id => ids).delete
            to_delete.delete
        end
    end
end
