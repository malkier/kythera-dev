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
                    :class_name => NicknameService::Nickname
    end

    module NicknameService
        class Error                  < Exception; end
        class NickExistsError        < Error;     end
        class NickNotRegisteredError < Error;     end
        class ExceedsNickCountError  < Error;     end

        class Nickname < Sequel::Model(:nickserv_nicknames)
            PREFIX = $config.nickserv.prefix || 'nickserv'

            many_to_one :account

            def self.register(nick, password, account)
                begin
                    account = Account.identify!(account, password)
                rescue Account::NoSuchLoginError
                    account = Account.register!(account, password)
                end

                if limit and
                   limit != :unlimited and
                   Nickname[:account => account].count > limit
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

            def self.drop(nick, password, account)
                account = Account.identify!(account, password)
                ds = Nickname[:account => account, :nickname => nick]

                if ds.empty?
                    msg = "#{nick} is not registered to #{account}"
                    raise NickNotRegisteredError, msg
                end

                nickname = ds.first
                nickname.delete
            end

            def self.limit
                $config.nickserv.limit
            end
            def limit; self.class.limit end

            def self.hold?(account)
                account = Account.resolve(account)
                account["#{PREFIX}.hold"]
            end

            def self.enable_hold(account)
                account = Account.resolve(account)
                account["#{PREFIX}.hold"] = true
            end

            def self.disable_hold(account)
                account = Account.resolve(account)
                account.delete("#{PREFIX}.hold")
            end

            def hold?
                self.class.hold?(account)
            end

            def enable_hold
                self.class.enable_hold(account)
            end

            def disable_hold
                self.class.disable_hold(account)
            end
        end

        class Helper < Account::Helper
            def hold?
                NicknameService.hold?(@account)
            end

            def enable_hold
                NicknameService.enable_hold(@account)
            end

            def disable_hold
                NicknameService.disable_hold(@account)
            end

            def nicknames
                Nickname[:account => account].all.to_a
            end

            def register(nick, password)
                NicknameService.register(nick, password, @account)
            end

            def drop(nick, password)
                NicknameService.drop(nick, password, @account)
            end
        end

        Account.register_resolver do |acct_to_resolve|
            nick = Nickname[:nickname => acct_to_resolve.to_s].first
            return nil unless nick

            nick.account
        end

        Account.before_drop do |account|
            Nickname.where(:account => account).delete
        end

        Account.helper [:nickserv, :ns], Helper
    end
end
