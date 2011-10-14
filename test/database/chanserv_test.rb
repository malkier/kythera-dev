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
require File.expand_path('../../lib/kythera/service/chanserv/database', dir)

check_timestamp = Proc.new do |timestamp, check|
  n = (check || Time.now).to_i
  t = timestamp.to_i

  # close enough I guess, these tests should be all but instantaneous
  n == t or n == (t+1)
end

require 'logger'
#$db.loggers << Logger.new($stdout)

context :database do
  setup do
    $_daemon_block.call
    $config.me.logging = :debug
    configure_test { service :chanserv }

    $db.run 'DELETE FROM chanserv_flags'
    $db.run 'DELETE FROM chanserv_privileges'
    $db.run 'DELETE FROM chanserv_channels'
    $db.run 'DELETE FROM account_fields'
    $db.run 'DELETE FROM accounts'

    Database::Account.register('sycobuny@malkier.net',    'password')
    Database::Account.register('rakaur@malkier.net',      'password')
    Database::Account.register('andrew12@malkier.net',    'password')
    Database::Account.register('justin@othius.com',       'password')
    Database::Account.register('dKingston02@malkier.net', 'password')
    Database::Account.register('rintaun@projectxero.net', 'password')
  end

  helper(:sycobuny)  { Database::Account[:email => 'sycobuny@malkier.net']    }
  helper(:rakaur)    { Database::Account[:email => 'rakaur@malkier.net']      }
  helper(:andrew)    { Database::Account[:email => 'andrew12@malkier.net']    }
  helper(:jufineath) { Database::Account[:email => 'justin@othius.com']       }
  helper(:xiphias)   { Database::Account[:email => 'dKingston02@malkier.net'] }
  helper(:rintaun)   { Database::Account[:email => 'rintaun@projectxero.net'] }

  helper(:malkier) do |*create|
    founders, successors, regulars = *create
    channel = Database::ChannelService::Channel.register(rakaur, '#malkier')

    if founders
      channel.grant(rakaur, :founder) || channel.grant(sycobuny, :founder)
    end

    if successors
      channel.grant(rintaun, :successor) || channel.grant(jufineath, :successor)
    end

    if regulars
      channel.grant(andrew, :autoop) || channel.grant(xiphias, :autovoice)
    end

    Database::ChannelService::Channel.where(:name => '#malkier').first
  end

  context 'registers channels' do
    setup { malkier }

    asserts_topic.kind_of Database::ChannelService::Channel
    asserts(:registered)    { check_timestamp.call(topic.registered)    }
    asserts(:last_activity) { check_timestamp.call(topic.last_activity) }
    asserts('default founder is automatically set') do
      rakaur.cs.founder?(topic)
    end

    asserts('registering a duplicate channel') do
      malkier
    end.raises(Database::ChannelService::ChannelExistsError)
  end

  context 'drops channels' do
    setup { malkier }

    asserts('channel drop command executes') do
      Database::ChannelService::Channel.drop(topic)
    end

    asserts('dropped channel') do
      Database::ChannelService::Channel.resolve('#malkier')
    end.nil
  end

  context 'resolves channels' do
    setup { malkier }
    helper(:c) { Database::ChannelService::Channel }

    asserts('finding by ID')     { c.resolve(topic.id)   == topic }
    asserts('finding by name')   { c.resolve(topic.name) == topic }
    asserts('finding by object') { c.resolve(topic)      == topic }
  end

  context 'has channel flags' do
    setup do
      channel = malkier
      channel[:website] = 'http://www.malkier.net'
      channel[:hold]    = true
      channel[:mlock]   = '+tn'

      channel
    end

    asserts('website')   { topic[:website] }.equals 'http://www.malkier.net'
    asserts('hold')      { topic[:hold]    }
    asserts('mlock')     { topic[:mlock]   }.equals '+tn'
    asserts('bad flag')  { topic[:bad] }.nil
    asserts('flag list') { topic.flag_list.sort }.equals %w(hold mlock website)

    context 'which can be deleted deliberately' do
      hookup { topic.delete_flag(:website) }
      asserts('website')   { topic[:website] }.nil
      asserts('hold')      { topic[:hold]    }
      asserts('mlock')     { topic[:mlock]   }.equals '+tn'
      asserts('bad flag')  { topic[:bad] }.nil
      asserts('flag list') { topic.flag_list.sort }.equals %w(hold mlock)
    end

    context 'which can be deleted by setting to false' do
      hookup { topic[:hold] = false }
      asserts('hold')      { topic[:hold]    }.nil
      asserts('mlock')     { topic[:mlock]   }.equals '+tn'
      asserts('flag list') { topic.flag_list.sort }.equals %w(mlock website)
    end

    context 'which can be deleted by setting to nil' do
      hookup { topic[:mlock] = nil }
      asserts('mlock')     { topic[:mlock]   }.nil
      asserts('flag list') { topic.flag_list.sort }.equals %w(hold website)
    end
  end

  context 'has chanserv privileges' do
    helper(:granted)          { ChannelService::PRIVILEGES[0] }
    helper(:helper_granted)   { ChannelService::PRIVILEGES[1] }
    helper(:not_granted)      { ChannelService::PRIVILEGES[2] }
    helper(:c_granted)        { ChannelService::CHANNEL_PRIVILEGES[-1] }
    helper(:c_helper_granted) { ChannelService::CHANNEL_PRIVILEGES[-2] }
    helper(:c_not_granted)    { ChannelService::CHANNEL_PRIVILEGES[-3] }

    setup do
      channel = malkier

      ##
      # grant global privileges
      Database::ChannelService::Channel.grant(sycobuny, granted)
      sycobuny.cs.grant(helper_granted)

      ##
      # grant channel privileges
      channel.grant(sycobuny, c_granted)
      sycobuny.cs.grant(c_helper_granted, channel)

      channel
    end

    ##
    # global privileges - direct
    asserts('acct has assigned global chanserv privilege') do
      Database::ChannelService::Channel.has_privilege?(sycobuny, granted)
    end

    asserts('acct has helper assigned global chanserv privilege') do
      Database::ChannelService::Channel.has_privilege?(sycobuny, granted)
    end

    denies('acct has unassigned global chanserv privilege') do
      Database::ChannelService::Channel.has_privilege?(sycobuny, not_granted)
    end

    ##
    # channel privileges - direct
    asserts('acct has assigned channel privilege') do
      topic.has_privilege?(sycobuny, c_granted)
    end

    asserts('acct has helper assigned channel privilege') do
      topic.has_privilege?(sycobuny, c_helper_granted)
    end

    denies('acct has unassigned privilege') do
      topic.has_privilege?(sycobuny, c_not_granted)
    end

    ##
    # global privileges - helper
    asserts('acct helper has global chanserv privilege method') do
      sycobuny.cs.send("#{granted}?".to_sym)
    end

    asserts('acct helper has global chanserv privilege method') do
      sycobuny.cs.send("#{helper_granted}?".to_sym)
    end

    denies('acct helper has global unassigned chanserv privilege method') do
      sycobuny.cs.send("#{not_granted}?".to_sym)
    end

    ##
    # channel privileges - helper
    asserts('acct helper has channel privilege method') do
      sycobuny.cs.send("#{c_granted}?".to_sym, topic)
    end

    asserts('acct helper has helper assigned channel privilege method') do
      sycobuny.cs.send("#{c_helper_granted}?".to_sym, topic)
    end

    denies('acct helper has unassigned privilege method') do
      sycobuny.cs.send("#{c_not_granted}?".to_sym, topic)
    end

    context 'that can be revoked' do
      hookup do
        Database::ChannelService::Channel.revoke(sycobuny, granted)
        topic.revoke(sycobuny, c_granted)

        sycobuny.cs.revoke(helper_granted)
        sycobuny.cs.revoke(c_helper_granted, topic)
      end

      ##
      # global privileges - direct
      denies('acct has revoked global chanserv privilege') do
        Database::ChannelService::Channel.has_privilege?(sycobuny, granted)
      end

      denies('acct has helper revoked global chanserv privilege') do
        Database::ChannelService::Channel.has_privilege?(sycobuny, granted)
      end

      denies('acct has unassigned global chanserv privilege') do
        Database::ChannelService::Channel.has_privilege?(sycobuny, not_granted)
      end

      ##
      # channel privileges - direct
      denies('acct has revoked channel privilege') do
        topic.has_privilege?(sycobuny, c_granted)
      end

      denies('acct has helper revoked channel privilege') do
        topic.has_privilege?(sycobuny, c_helper_granted)
      end

      denies('acct has unassigned privilege') do
        topic.has_privilege?(sycobuny, c_not_granted)
      end

      ##
      # global privileges - helper
      denies('acct helper has global chanserv privilege method') do
        sycobuny.cs.send("#{granted}?".to_sym)
      end

      denies('acct helper has global chanserv privilege method') do
        sycobuny.cs.send("#{helper_granted}?".to_sym)
      end

      denies('acct helper has global unassigned chanserv privilege method') do
        sycobuny.cs.send("#{not_granted}?".to_sym)
      end

      ##
      # channel privileges - helper
      denies('acct helper has channel privilege method') do
        sycobuny.cs.send("#{c_granted}?".to_sym, topic)
      end

      denies('acct helper has helper assigned channel privilege method') do
        sycobuny.cs.send("#{c_helper_granted}?".to_sym, topic)
      end

      denies('acct helper has unassigned privilege method') do
        sycobuny.cs.send("#{c_not_granted}?".to_sym, topic)
      end
    end
  end

  #context 'provides chanserv succession' do
  #end

  context 'cleaning up chanserv tests...' do
    setup do
      $db.run 'DELETE FROM chanserv_flags'
      $db.run 'DELETE FROM chanserv_privileges'
      $db.run 'DELETE FROM chanserv_channels'
      $db.run 'DELETE FROM account_fields'
      $db.run 'DELETE FROM accounts'
    end
  end
#Database::ChannelService.on_succession
#  (Account.before_drop handler)
end
