#
# kythera: services for IRC networks
# lib/kythera/service/operserv/database.rb: database models for operserv
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Database
    #
    # This module provides no models, but simply an interface to grant and
    # revoke specific flags from the database. It's essentially syntactic sugar
    # around the AccountField mechanism in Account.
    #
    module OperatorService
        #
        # The prefix we use for storing any keys in an AccountField.
        #
        # @private
        #
        PREFIX = 'operserv'

        #
        # Grants a privilege to an account.
        #
        # @param [Account] account The account being granted a privilege
        # @param [String, #to_s] privilege The privilege being granted
        # @example
        #   account = Account.resolve('rakaur@malkier.net')
        #   OperatorService.grant(account, :akill)
        #
        def self.grant(account, privilege)
            account["#{PRIV_PREFIX}.#{privilege}"] = true
        end

        #
        # Revokes a privilege from an account.
        #
        # @param [Account] account The account having a privilege revoked
        # @param [String, #to_s] privilege The privilege being revoked
        # @example
        #   account = Account.resolve('sycobuny@malkier.net')
        #   OperatorService.revoke(account, :stats)
        #
        def self.revoke(account, privilege)
            account.delete_flag("#{PRIV_PREFIX}.#{privilege}")
        end

        #
        # Helper for Account objects.
        #
        class Helper < Account::Helper
            #
            # This defines a method for each privilege so that the privilege can
            # be checked quickly, based on the values in
            # OperatorService::PRIVILEGES.
            #
            # @example
            #   account = Account.resolve('rakaur@malkier.net')
            #   account.os.akill? # true
            #   account = Account.resolve('sycobuny@malkier.net')
            #   account.os.stats? # false
            ::OperatorService::PRIVILEGES.each do |privilege|
                meth = "#{privilege.to_s}?".to_sym
                define_method(meth) do
                    @account["#{PREFIX}.#{privilege}"]
                end
            end

            #
            # Shortcut to grant an account a privilege.
            #
            # @param [String, #to_s] privilege The privilege to grant
            # @example
            #   account = Account.resolve('rakaur@malkier.net')
            #   account.os.grant(:akill)
            #
            def grant(privilege)
                OperatorService.grant(@account, privilege)
            end

            #
            # Shortcut to revoke a privilege from an account
            #
            # @param [String, #to_s] privilege The privilege to revoke
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   account.os.revoke(:stats)
            #
            def revoke(privilege)
                OperatorService.revoke(@account, privilege)
            end
        end

        # Register operserv's helper with `operserv` and `os` methods.
        Account.helper [:operserv, :os], Helper
    end
end
