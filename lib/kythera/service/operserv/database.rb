# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/operserv/database.rb: database models for operserv
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.md
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
            assert { :account }
            account["#{PREFIX}.#{privilege}"] = true
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
            assert { :account }
            account.delete_field("#{PREFIX}.#{privilege}")
        end

        def self.has_privilege?(account, privilege)
            assert { account }
            !! account["#{PREFIX}.#{privilege}"]
        end

        #
        # Helper for Account objects.
        #
        class Helper < Account::Helper
            #
            # Tracks whether this object has been created before, to cache
            # setting up the methods for this class.
            #
            @@first_run = true

            def initialize(*args)
                #
                # This defines a method for each privilege so that the privilege
                # can be checked quickly, based on the values in
                # OperatorService::PRIVILEGES.
                #
                # @example
                #   account = Account.resolve('rakaur@malkier.net')
                #   account.os.akill? # true
                #   account = Account.resolve('sycobuny@malkier.net')
                #   account.os.stats? # false
                ::OperatorService::PRIVILEGES.each do |privilege|
                    meth = "#{privilege.to_s}?".to_sym

                    self.class.instance_eval do
                        define_method(meth) do
                            OperatorService.has_privilege?(@account, privilege)
                        end
                    end
                end if @@first_run

                @@first_run = false
                super
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
