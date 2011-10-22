# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/database/nickserv_test.rb: tests the nickserv's database API.
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

dir = File.dirname(__FILE__)
require File.expand_path('../teststrap', dir)
require File.expand_path('../../lib/kythera/service/nickserv/database', dir)

context :nickserv_db do
  setup do
    $_daemon_block.call
    $_logger_setup.call
    configure_test { service(:nickserv) { limit 5 } }

    $db.run 'DELETE FROM nickserv_nicknames'
    $db.run 'DELETE FROM account_fields'
    $db.run 'DELETE FROM accounts'
  end

  helper(:klass) { Database::NicknameService::Nickname }
  helper(:ts) do |ts, chk|
    chk = chk.to_i
    ts  = ts.to_i

    # close enough I guess, these tests should be all but instantaneous, but if
    # not 1 second should be enough leeway
    chk == ts or chk == (ts+1)
  end

  context 'registers nicknames' do
    setup do
      $state.srv_cfg[:nickserv].limit = 2
      klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
    end

    asserts_topic.kind_of Database::NicknameService::Nickname
    asserts('account obj is correct') do
      topic.account.email
    end.equals 'sycobuny@malkier.net'
    asserts(:nickname).equals 'sycobuny'

    asserts('resolver was registered') do
      topic.account == Database::Account.resolve('sycobuny')
    end

    asserts('failing authentication') do
      klass.register('anything', 'badpass', 'sycobuny@malkier.net')
    end.raises(Database::Account::PasswordMismatchError)

    asserts('registering a duplicate nickname by user') do
      klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
    end.raises(Database::NicknameService::NickExistsError)

    asserts('registering a duplicate nickname by other') do
      klass.register('sycobuny', 'password', 'rakaur@malkier.net')
    end.raises(Database::NicknameService::NickExistsError)

    asserts('registering too many nicks') do
      klass.register('acceptable', 'password', 'sycobuny@malkier.net')
      klass.register('excess', 'password', 'sycobuny@malkier.net')
    end.raises(Database::NicknameService::ExceedsNickCountError)
  end

  context 'measures nickname limits' do
    setup do
      $state.srv_cfg[:nickserv].limit = 3
      klass.register('sycobuny@malkier.net', 'password', 'sycobuny')
    end

    asserts('class limit') { klass.limit }.equals 3
    asserts(:limit).equals 3
  end

  context 'drops nicknames' do
    hookup do
      klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
      klass.register('sycobuny_', 'password', 'sycobuny@malkier.net')
      klass.drop('sycobuny', 'password', 'sycobuny@malkier.net')
    end

    denies('nickname exists') { ! klass[:nickname => 'sycobuny'].nil? }
    asserts('account exists') { !! Database::Account.resolve('sycobuny_') }

    asserts('does not drop accounts with bad password') do
      klass.drop('sycobuny_', 'badpass', 'sycobuny@malkier.net')
    end.raises(Database::Account::PasswordMismatchError)

    asserts('does not drop accounts by non-owner') do
      klass.register('rakaur', 'password', 'rakaur@malkier.net')
      klass.drop('sycobuny_', 'password', 'rakaur@malkier.net')
    end.raises(Database::NicknameService::NickNotRegisteredError)
  end

  context 'drops accounts where last nick was dropped' do
    hookup do
      klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
      klass.register('sycobuny_', 'password', 'sycobuny@malkier.net')
      klass.drop('sycobuny', 'password', 'sycobuny@malkier.net')
      klass.drop('sycobuny_', 'password', 'sycobuny@malkier.net')
    end

    denies('nickname1 exists') { ! klass[:nickname => 'sycobuny'].nil? }
    denies('nickname2 exists') { ! klass[:nickname => 'sycobuny'].nil? }
    denies('account exists')   { ! Database::Account.empty? }
  end

  context 'marks accounts as held' do
    hookup do
      klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
      klass.register('syco', 'password', 'sycobuny@malkier.net').enable_hold

      klass.register('rakaur', 'password', 'rakaur@malkier.net')
      klass.enable_hold(Database::Account.resolve('rakaur'))
    end

    asserts('saved across all nicknames') do
      klass[:nickname => 'sycobuny'].hold? and
      klass[:nickname => 'syco'].hold?
    end

    asserts('saved via account object') do
      klass.hold?(Database::Account.resolve('rakaur'))
    end

    context 'and unmarks them' do
      hookup do
        klass[:nickname => 'syco'].disable_hold
        klass.disable_hold(Database::Account.resolve('rakaur'))
      end

      asserts('saved across all nicknames') do
        (not klass[:nickname => 'sycobuny'].hold?) and
        (not klass[:nickname => 'syco'].hold?)
      end

      asserts('saved via account object') do
        not klass.hold?(Database::Account.resolve('rakaur'))
      end
    end
  end

  context :helper do
    context 'enables hold' do
      setup do
        n = klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
        t = n.account
        t.ns.enable_hold
        t
      end
      asserts('hold is enabled') { topic.ns.hold? }

      context 'and disables it' do
        hookup { topic.ns.disable_hold }
        denies('hold is enabled') { topic.ns.hold? }
      end
    end

    context 'returns registered nicknames' do
      setup do
        1.upto(3) do |i|
          klass.register("sycobuny#{i}", 'password', 'sycobuny@malkier.net')
        end
        Database::Account.resolve('sycobuny@malkier.net')
      end
    end

    context 'registers additional nicknames' do
      setup do
        n = klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
        t = n.account
        %w(1 2).each { |i| t.ns.register("sycobuny#{i}", 'password') }
        t
      end

      asserts('all nicknames listed') do
        nicks = topic.ns.nicknames

        nicks[0].is_a?(klass) and
        nicks[1].is_a?(klass) and
        nicks[2].is_a?(klass) and
        nicks.collect(&:nickname).sort == %w(sycobuny sycobuny1 sycobuny2)
      end

      context 'and drops them' do
        hookup do
          topic.ns.drop('sycobuny1', 'password')
        end

        asserts('all nicknames listed') do
          nicks = topic.ns.nicknames
          nicks.collect(&:nickname).sort == %w(sycobuny sycobuny2)
        end
      end
    end
  end

  context 'drops related nicknames' do
    hookup do
      klass.register('sycobuny', 'password', 'sycobuny@malkier.net')
      Database::Account.admin_drop('sycobuny@malkier.net')
    end
    asserts('nickname no longer exists') { klass.empty? }
  end

  context 'cleaning up...' do
    hookup do
      $db.run 'DELETE FROM nickserv_nicknames'
      $db.run 'DELETE FROM account_fields'
      $db.run 'DELETE FROM accounts'
    end
  end
end

#  (Account.before_drop handler)
