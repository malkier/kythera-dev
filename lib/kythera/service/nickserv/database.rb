# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
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
    #
    # This module creates and manages nicknames associated with accounts. It
    # assumes that it provides a central front-end to the core Account class,
    # and as such requires that an account registered through this service have
    # at least one nickname, and will drop accounts automatically when they drop
    # their last nickname. It supports a "hold" field for ensuring registration
    # is permanent, though this API may change.
    #
    module NicknameService
        #
        # The prefix we use for storing any keys in an AccountField.
        #
        # @private
        #
        PREFIX = 'nickserv'

        #
        # The base of all errors that might happen in this module. Probably
        # should not be used directly.
        #
        # @private
        #
        class Error                  < Exception; end

        #
        # When a nickname exists and someone still tries to create it, this
        # exception will be raised.
        #
        class NickExistsError        < Error;     end

        #
        # When someone attempts to perform an operation on a nickname that does
        # not exist, this exception will be raised.
        #
        class NickNotRegisteredError < Error;     end

        #
        # When a user attempts to register too many accounts (variable, depends
        # on configuration), this exception will be raised.
        #
        class ExceedsNickCountError  < Error;     end

        #
        # This is the class that drives most of the work on the database side of
        # this service.
        #
        class Nickname < Sequel::Model(:nickserv_nicknames)
            many_to_one :account, :class_name => Account

            #
            # Registers a nickname to an account. This method also implicitly
            # creates an account object if one does not exist. Depending on the
            # configuration setting for $config.nickserv.limit, the user may
            # not be allowed to register another nickname. Nicknames are unique
            # across the entire service (ie, two users cannot have the same
            # nickname). An exception will be raised if the user cannot register
            # the account.
            #
            # @param [String] nick The nickname to register
            # @param [String] password The password for the account
            # @param [String] acount The account to register this nickname to
            # @return [Nickname] The newly-registered nickname
            # @raise [ExceedsNickCountError] If the user has too many nicknames
            # @raise [NickExistsError] If the nick has already been registered
            # @example
            #   nick     = 'rakaur'
            #   password = 'steveisawesome'
            #   account  = 'rakaur@malkier.net'
            #   nickname = Nickname.register(nick, password, account)
            #
            def self.register(nick, password, account)
                begin
                    account = Account.authenticate(account, password)
                rescue Account::ResolveError
                    account = Account.register(account, password)
                rescue Account::AlreadyAuthenticatedError
                end

                if limit and
                   limit != :unlimited and
                   filter(:account => account).count >= limit
                    raise ExceedsNickCountError
                end

                if Nickname[:nickname => nick]
                    raise NickExistsError
                end

                nickname = Nickname.new
                nickname.account  = account
                nickname.nickname = nick
                nickname.save

                nickname
            end

            #
            # Deletes a nickname from an account. If it was the last nickname,
            # it implicitly deletes the account. It raises an error if a user
            # attempts to drop an account that they do not have access to.
            #
            # @param [String] nick The nickname to drop
            # @param [String] password The password to the account
            # @param [String] account The login to the account
            # @raise [NickNotRegisteredError] If the nickname's not registered
            #   to that account
            # @example
            #   nick     = 'heartsteve'
            #   password = 'steveisawesome'
            #   account  = 'rakaur@malkier.net'
            #   Nickname.drop(nick, password, account)
            #
            def self.drop(nick, password, account)
                begin
                    account = Account.authenticate(account, password)
                rescue Account::AlreadyAuthenticatedError
                end

                ds = Nickname.filter(:account => account, :nickname => nick)

                if ds.empty?
                    msg = "#{nick} is not registered to #{account.email}"
                    raise NickNotRegisteredError, msg
                end

                nickname = ds.first
                nickname.delete

                Account.admin_drop(account) if account.nickserv_nicknames.empty?
            end

            #
            # Syntactic sugar to make getting `$config.nickserv.limit` easier.
            #
            # @return [Integer, Symbol] The value of the config parameter
            # @example
            #   account = Account.resolve('rakaur')
            #   limit   = Nickname.limit
            #   $log.debug("rakaur has #{account.nicknames.count - limit} " +
            #              "open nickname slots")
            #
            def self.limit
                $config.nickserv.limit
            end

            #
            # Syntactic sugar to make getting `$config.nickserv.limit` easier.
            #
            # @return [Integer, Symbol] The value of the config parameter
            # @example
            #   account  = Account.resolve('rakaur')
            #   nickname = account.nicknames.first
            #   limit    = nickname.limit
            #   $log.debug("rakaur has #{account.nicknames.count - limit} " +
            #              "open nickname slots")
            #
            def limit; self.class.limit end

            #
            # Holds an account; ie, makes it permanent.
            #
            # @param [Account] account The account to hold
            # @example
            #   account = Account.resolve('rakaur')
            #   Nickname.enable_hold(account)
            #
            def self.enable_hold(account)
                assert { :account }
                account["#{PREFIX}.hold"] = true
            end

            #
            # Ensures an account is not held; ie, it can expire like a normal
            # account. This method does not drop an account.
            #
            # @param [Account] account The account to release
            # @example
            #   account = Account.resolve('sycobuny')
            #   Nickname.disable_hold(account)
            #
            def self.disable_hold(account)
                assert { :account }
                account.delete_field("#{PREFIX}.hold")
            end

            #
            # Checks whether an account is held; ie, permanent.
            #
            # @return [True, False]
            # @example
            #   account = Account.resolve('rakaur')
            #   Nickname.hold?(account) # true
            #
            def self.hold?(account)
                account["#{PREFIX}.hold"]
            end

            #
            # Enables holding on the account associated with this nickname.
            #
            # @example
            #   nickname = Account.resolve('rakaur').ns.nicknames.first
            #   nickname.enable_hold
            #
            def enable_hold
                self.class.enable_hold(account)
            end

            #
            # Disables holding on the account associated with this nickname.
            #
            # @example
            #   nickname = Account.resolve('rakaur').nicknames.first
            #   nickname.disable_hold
            #
            def disable_hold
                self.class.disable_hold(account)
            end

            #
            # Checks whether the account associated with this nikcname is held.
            #
            # @example
            #   nickname = Account.resolve('rakaur').ns.nicknames.first
            #   nickname.hold?
            #
            def hold?
                self.class.hold?(account)
            end
        end

        #
        # Helper for Account objects.
        #
        class Helper < Account::Helper
            #
            # Shortcut for enabling hold on the nickname's account.
            #
            # @example
            #   account = Account.resolve('rakaur')
            #   account.ns.enable_hold
            #
            def enable_hold
                Nickname.enable_hold(@account)
            end

            #
            # Shortcut for disabling hold on the nickname's account.
            #
            # @example
            #   account = Account.resolve('rakaur')
            #   account.ns.disable_hold
            #
            def disable_hold
                Nickname.disable_hold(@account)
            end

            #
            # Shortcut for determining whether the nickname's account is held.
            #
            # @return [True, False]
            # @example
            #   account = Account.resolve('rakaur')
            #   account.ns.hold?
            #
            def hold?
                Nickname.hold?(@account)
            end

            #
            # Get a list of all of the nickname's account's nicknames.
            #
            # @return [Array] The list of nickname's
            # @example
            #   account = Account.resolve('rakaur')
            #   account.ns.nicknames
            #
            def nicknames
                Nickname.filter(:account => @account).all
            end

            #
            # Register a new nickname to this nickname's account. Requires the
            # password for the account to ensure that only the account owner
            # can add a nickname. As it simply wraps `Nickname.register`, it can
            # raise the same errors that method can.
            #
            # @param [String] nick The nickname to register
            # @param [String] password The account's password
            # @return [Nickname] The newly registered nickname
            # @raise [ExceedsNickCountError] If the user has too many nicknames
            # @raise [NickExistsError] If the nick has already been registered
            # @example
            #   account = Account.resolve('rakaur')
            #   account.ns.register('lanfear', 'steveisawesome')
            #
            def register(nick, password)
                Nickname.register(nick, password, @account)
            end

            #
            # Drop a nickname associated with this account. It wraps
            # `Nickname.drop` and has the potential to raise the same errors
            # that method does.
            #
            # @note
            #   This method has the potential to drop the account from the
            #   database entirely, if it is the last nickname registered to the
            #   account.
            #
            # @param [String] nick The nickname to drop
            # @param [String] password The password for the account
            # @raise [NickNotRegisteredError] If the nickname's not registered
            #   to that account
            #
            def drop(nick, password)
                Nickname.drop(nick, password, @account)
            end
        end

        # Register a resolver so that `Account.resolve` can take a nickname.
        Account.register_resolver do |acct_to_resolve|
            nick = Nickname[:nickname => acct_to_resolve.to_s]
            next unless nick

            nick.account
        end

        # Drop all nicknames before an account goes away.
        Account.before_drop do |account|
            Nickname.where(:account => account).delete
        end

        # Register nickserv's helper with `nickserv` and `ns` methods.
        Account.helper [:nickserv, :ns], Helper
    end

    class Account
        one_to_many :nickserv_nicknames,
                    :class_name => NicknameService::Nickname
    end
end
