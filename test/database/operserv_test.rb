# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/database/operserv_test.rb: tests the operserv's database API.
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

dir = File.dirname(__FILE__)
require File.expand_path('../teststrap', dir)
require File.expand_path('../../lib/kythera/service/operserv/database', dir)

context :database do
  setup do
    $_daemon_block.call
    $_logger_setup.call
    configure_test { service :operserv }

    $db.run 'DELETE FROM account_fields'
    $db.run 'DELETE FROM accounts'

    Database::Account.register('sycobuny@malkier.net', 'password')
  end

  helper(:cls)   { Database::OperatorService }
  helper(:acct)  { Database::Account.first }
  helper(:privs) { OperatorService::PRIVILEGES }

  context 'grants operserv privileges' do
    setup do
      cls.grant(acct, privs[0])
    end

    denies('account has unassigned privilege') do
      cls.has_privilege?(acct, privs[1])
    end

    asserts('account has newly-assigned privilege') do
      cls.has_privilege?(acct, privs[0])
    end

    context 'and revokes them' do
      setup do
        cls.revoke(acct, privs[0])
      end

      denies('account has old unassigned privilege') do
        cls.has_privilege?(acct, privs[1])
      end

      denies('account has newly-revoked privilege') do
        cls.has_privilege?(acct, privs[0])
      end
    end
  end

  context 'operserv helper' do
    setup do
      acct.os
    end

    asserts_topic.kind_of Database::OperatorService::Helper

    context 'grants operserv privileges' do
      setup do
        acct.os.grant(privs[0])
      end

      denies('account has unassigned privilege') do
        acct.os.send("#{privs[1]}?".to_sym)
      end

      asserts('account has newly-assigned privilege') do
        acct.operserv.send("#{privs[0]}?".to_sym)
      end

      context 'and revokes them' do
        setup do
          acct.operserv.revoke(privs[0])
        end

        denies('account has old unassigned privilege') do
          acct.operserv.send("#{privs[1]}?".to_sym)
        end

        denies('account has newly-revoked privilege') do
          acct.os.send("#{privs[0]}?".to_sym)
        end
      end
    end
  end
end
