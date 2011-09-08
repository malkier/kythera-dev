#
# kythera: services for IRC networks
# lib/kythera/service/nickserv/database.rb: database models for nickserv
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Database
    class Account
        one_to_many :nickserv_nicknames,
                    :class_name => NickServ::Nickname
    end

    module NickServ
        class Error                 < Exception; end
        class NickExistsError       < Error;     end
        class ExceedsNickCountError < Error;     end

        class Nickname < Sequel::Model(:nickserv_nicknames)
            many_to_one :account

            def self.register(account, nick)
                account = Account.resolve(account)

                if Nickname[:account => account].count > limit
                    raise ExceedsNickCountError
                end

                if Nickname[:nickname => nick].first
                    raise NickExistsError
                end

                nickname = Nickname.new
                nickname.account  = account
                nickname.nickname = nick
                nickname.save

                nickname
            end

            def self.limit
                $config.nickserv.limit
            end

            def limit
                self.limit
            end
        end

        Account.register_resolver do |acct_to_resolve|
            Nickname[:nickname => acct_to_resolve.to_s].first
        end

        Account.before_unregister do |account|
            Nickname.where(:account => account).delete
        end
    end
end
