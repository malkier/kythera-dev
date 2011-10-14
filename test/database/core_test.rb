# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/database/core_test.rb: tests the core database models' API
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('../teststrap', File.dirname(__FILE__))

#
# a function to check that a timestamp is "close enough" (no more than a second
# off, in case the tests take a bit longer than expectd)
#
check_timestamp = Proc.new do |timestamp, check|
  n = (check || Time.now).to_i
  t = timestamp.to_i

  # close enough I guess, these tests should be all but instantaneous
  n == t or n == (t+1)
end

#
# accounts we'll be using all over the place and that I'm too lazy to keep
# retyping.
register = Proc.new do |who|
  acct = Database::Account

  a = acct.register('sycobuny@malkier.net', 'test') if who == :sycobuny
  a = acct.register('rakaur@malkier.net', 'asdf')   if who == :rakaur

  a
end

#
# Test module for registering a helper that can verify that helpers work.
#
# @private
#
module AccountsTestHelper
  #
  # Test class for registering a helper that can verify that helpers work.
  #
  # @private
  #
  class HelperTest < Database::Account::Helper
    #
    # Test method for verifying that helpers work.
    #
    # @private
    #
    def test
      @account
    end
  end
end

context :database do
  setup do
    $_daemon_block.call
    $_logger_setup.call
    $db.run 'DELETE FROM account_fields'
    $db.run 'DELETE FROM accounts'
  end

  context 'creates account objects' do
    setup do
      Database::Account.new
    end

    asserts_topic.kind_of Database::Account
    asserts(:users).kind_of Array
    asserts(:users).empty
  end

  context 'registers accounts' do
    setup do
      register.call(:sycobuny)
    end

    asserts_topic.kind_of Database::Account
    asserts(:email).equals 'sycobuny@malkier.net'
    asserts(:registered) { check_timestamp.call(topic.registered) }
    asserts(:last_login) { check_timestamp.call(topic.last_login) }

    asserts('registering a duplicate account') do
      register.call(:sycobuny)
    end.raises(Database::Account::LoginExistsError)
  end

  context 'sets up an account resolver' do
    setup do
      Database::Account.register_resolver do |value|
        if value == :success
          Database::Account[:email => 'sycobuny@malkier.net']
        else
          nil
        end
      end
      register.call(:sycobuny)
    end

    helper(:success) { Database::Account.resolve(:success) }
    helper(:failure) { Database::Account.resolve(:failure) }

    asserts('resolves good values') { success == topic }
    asserts('failure to resolve bad values') do
      failure
    end.raises(Database::Account::ResolveError)
  end

  context 'sets up an account helper' do
    setup do
      Database::Account.helper [:ht, :helptest], AccountsTestHelper::HelperTest
      register.call(:sycobuny)
    end

    asserts(:ht).kind_of AccountsTestHelper::HelperTest
    asserts(:helptest).kind_of AccountsTestHelper::HelperTest
    asserts('ht method returns the account') do
      topic.ht.test == topic
    end
  end

  context 'resolves accounts by existing methods' do
    setup do
      register.call(:sycobuny)
    end

    helper(:id)    { topic.id    }
    helper(:email) { topic.email }

    asserts('resolves account by ID') do
      Database::Account.resolve(id) == topic
    end

    asserts('resolves account by email') do
      Database::Account.resolve(email) == topic
    end

    asserts('resolves account by existing object') do
      Database::Account.resolve(topic) == topic
    end
  end

  context 'authenticates registered accounts' do
    setup do
      register.call(:sycobuny)
      register.call(:rakaur)
    end

    asserts('does not authenticate a user with the wrong password') do
      Database::Account.authenticate('sycobuny@malkier.net', 'failure!')
    end.raises(Database::Account::PasswordMismatchError)

    asserts('does not authenticate a non-existent user') do
      Database::Account.authenticate('baduser@badhost.net', 'failure!')
    end.raises(Database::Account::ResolveError)

    asserts('does not authenticate the wrong user for a password') do
      Database::Account.authenticate('rakaur@malkier.net', 'test')
    end.raises(Database::Account::PasswordMismatchError)

    asserts('authenticates a user with the right password') do
      Database::Account.authenticate('sycobuny@malkier.net', 'test').email ==
      'sycobuny@malkier.net'
    end
  end

  context 'drops registered accounts' do
    setup do
      register.call(:sycobuny)
      register.call(:rakaur)
    end

    context 'by user (using password)' do
      asserts('does not drop a user with the wrong password') do
        Database::Account.drop('sycobuny@malkier.net', 'failure!')
      end.raises(Database::Account::PasswordMismatchError)

      asserts('does not drop a non-existent user') do
        Database::Account.drop('baduser@badhost.net', 'failure!')
      end.raises(Database::Account::ResolveError)

      asserts('does not drop the wrong user with a password') do
        Database::Account.drop('rakaur@malkier.net', 'test')
      end.raises(Database::Account::PasswordMismatchError)

      asserts('drops a user with the right password') do
        Database::Account.drop('sycobuny@malkier.net', 'test')

        # make sure the user can no longer be located
        begin
          Database::Account.resolve('sycobuny@malkier.net')
        rescue Database::Account::ResolveError => e
          true
        else
          false
        end
      end
    end

    context 'by admin (no password)' do
      asserts('does not drop a non-existent user') do
        Database::Account.admin_drop('baduser@badhost.net')
      end.raises(Database::Account::ResolveError)

      asserts('drops an existing user') do
        Database::Account.admin_drop('rakaur@malkier.net')

        # make sure the user can no longer be located
        begin
          Database::Account.resolve('rakaur@malkier.net')
        rescue Database::Account::ResolveError => e
          true
        else
          false
        end
      end
    end

    context 'calls a before_drop handler' do
      setup do
        val = nil

        Database::Account.before_drop do
          val = 'Successful execution!'
        end

        # just to make sure we didn't just execute the before_drop
        val = nil

        Database::Account.admin_drop('sycobuny@malkier.net')
        val
      end

      asserts_topic.equals 'Successful execution!'
    end
  end

  context 'authenticates existing account objects' do
    setup do
      register.call(:sycobuny)
      register.call(:rakaur)
    end

    context '- not new objects by default' do
      setup do
        Database::Account.resolve('sycobuny@malkier.net')
      end
      denies(:authenticated?)
    end

    context '- validating passwords' do
      setup do
        Database::Account.resolve('sycobuny@malkier.net')
      end

      denies('bad password passes')   { topic.authenticates?('asdf') }
      asserts('good password passes') { topic.authenticates?('test') }
    end

    context '- uses passwords to authenticate' do
      setup do
        Database::Account.resolve('sycobuny@malkier.net')
      end

      asserts('bad password') do
        topic.authenticate('asdf')
      end.raises(Database::Account::PasswordMismatchError)

      asserts('good password validates') do
        topic.authenticate('test') == topic
      end

      asserts('cannot re-authenticate - bad pass') do
        topic.authenticate('asdf')
      end.raises(Database::Account::AlreadyAuthenticatedError)

      asserts('cannot re-authenticate - good pass') do
        topic.authenticate('test')
      end.raises(Database::Account::AlreadyAuthenticatedError)
    end

    context '- tells when accounts are authenticated' do
      setup do
        t = Database::Account.resolve('sycobuny@malkier.net')
        t.authenticate('test')
        t
      end

      asserts(:authenticated?)
      denies('new object is authenticated') do
        Database::Account.resolve(topic.email).authenticated?
      end
    end

    context '- logs out authenticated accounts' do
      setup do
        t = Database::Account.resolve('sycobuny@malkier.net')
        t.authenticate('test')
        t.logout!
        t
      end

      denies(:authenticated?)
    end
  end

  context 'verifies accounts' do
    setup do
      register.call(:sycobuny)
      t = Database::Account.resolve('sycobuny@malkier.net')
      t.verification = 'test_verification'
      t.save

      Database::Account.resolve('sycobuny@malkier.net')
    end

    denies(:verified?)
    denies('checks with bad token') { topic.verifies?('bad_verification') }
    denies(:verified?) # just to make sure nothing was written
    denies('new object is verified') do
      Database::Account.resolve('sycobuny@malkier.net').verified?
    end

    asserts('checks with good token') { topic.verifies?('test_verification') }
    denies(:verified?) # just to make sure nothing was written
    denies('new object is verified') do
      Database::Account.resolve('sycobuny@malkier.net').verified?
    end

    asserts do
      topic.verify('bad_verification')
    end.raises(Database::Account::BadVerificationError)
    denies(:verified?) # just to make sure nothing was written
    denies('new object is verified') do
      Database::Account.resolve('sycobuny@malkier.net').verified?
    end

    asserts('verifies with good token') { topic.verify('test_verification') }
    asserts(:verified?)
    asserts('new object is verified') do
      Database::Account.resolve('sycobuny@malkier.net').verified?
    end
  end

  context 'has associated fields' do
    setup do
      t = register.call(:sycobuny)
      t[:website]  = 'http://www.xzion.net/'
      t[:realname] = 'Stephen Belcher'
      t[:language] = 'English'
      t
    end

    asserts('empty values do not error') do
      topic[:empty].nil?
    end

    asserts('field list') do
      topic.field_list.sort
    end.equals ['language', 'realname', 'website']

    asserts('retrieves a value') do
      topic[:website] == 'http://www.xzion.net/'
    end

    asserts('deletes a value by setting it to nil') do
      topic[:realname] = nil
      topic[:realname].nil?
    end

    asserts('field list') do
      topic.field_list.sort
    end.equals ['language', 'website']

    asserts('deletes a value by setting it to false') do
      topic[:language] = false
      topic[:language].nil?
    end

    asserts('field list') do
      topic.field_list.sort
    end.equals ['website']

    asserts('deletes a value by delete_value') do
      topic.delete_field(:website)
      topic[:website].nil?
    end

    asserts(:field_list).empty
  end
end
