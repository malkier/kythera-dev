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
    module OperatorService
        PREFIX = $config.operserv.privilege_prefix || 'operserv'

        def self.grant(account, privilege)
            account = Account.resolve(account)
            account["#{PRIV_PREFIX}.#{privilege}"] = true
        end

        def self.revoke(account, privilege)
            account = Account.resolve(account)
            account.delete("#{PRIV_PREFIX}.#{privilege}")
        end

        class Helper < Account::Helper
            ::OperatorService::PRIVILEGES.each do |privilege|
                meth = "#{privilege.to_s}?".to_sym
                define_method(meth) do
                    @account["#{PREFIX}.#{privilege}"]
                end
            end

            def grant(privilege)
                OperatorService.grant(@account, privilege)
            end

            def revoke(privilege)
                OperatorService.revoke(@account, privilege)
            end
        end

        Account.helper [:operserv, :os], Helper
    end
end
