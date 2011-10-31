# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/userserv/commands.rb: implements userserv's commands
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

class UserService < Service
    private

    # XXX temporary
    def do_eval(user, params)
        code = params.join(' ')

        result = eval(code)

        snoop(:eval, user)

        privmsg(@user.key, @config.channel, "#{result.inspect}")
    end

    EMAIL_RE = /^[^@]+@[^.]+\..+$/

    # Register a new Account
    def do_register(user, params)
        # Did they send the right number of params?
        unless params.length == 2
            notice(@user.key, user.key, "Incorrect parameters for \2REGISTER\2")

            notice(@user.key, user.key,
                   'Syntax: REGISTER <email address> <password>')

            return
        end

        email, password = params

        # Does the email address look something like a real email address?
        unless email =~ EMAIL_RE
            notice(@user.key, user.key,
                   "Invalid email address for \2REGISTER\2")

            notice(@user.key, user.key,
                   'Syntax: REGISTER <email address> <password>')

            return
        end

        # Make sure the password is somewhat sane
        unless password.length >= 6
            notice(@user.key, user.key, 'Please select a password that is ' +
                   'at least six characters long')

            return
        end

        # Try to register the Account
        begin
            account = Database::Account.register(email, password)
        rescue Database::Account::AccountExistsError
            notice(@user.key, user.key, "The email address \2" + email +
                   "\2 is already registered to another account")

            return
        end

        # The Account was successfully created
        notice(@user.key, user.key, "You have successfully registered an " +
               "account to \2" + email + "\2")

        user.account = account
        account.users << user

        snoop(:register, user)
    end

    # Authenticate to an Account
    def do_auth(user, params)
        # Did they send the right number of params?
        unless params.length == 2
            notice(@user.key, user.key, "Incorrect parameters for \2AUTH\2")

            notice(@user.key, user.key,
                   'Syntax: AUTH <email address> <password>')

            return
        end

        email, password = params

        # Try to auth
        begin
            account = Database::Account.authenticate(email, password)
        rescue Exception
            notice(@user.key, user.key, "Invalid email or password given " +
                   "for \2" + email + "\2")

            return
        end

        # The Account was successfully authenticated
        notice(@user.key, user.key, "Authentication to \2" + email +
               "\2 successful")

        user.account = account
        account.users << user

        snoop(:auth, user)
    end
end
