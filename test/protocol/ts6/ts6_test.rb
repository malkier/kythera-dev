# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/protocol/ts6_test.rb: tests the Protocol::TS6 module
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require File.expand_path('../../teststrap', File.dirname(__FILE__))

context :ts6 do
  hookup do
    $_daemon_block.call
    $_uplink_block.call
    $_logger_setup.call

    require 'kythera/protocol/ts6'
    $config.uplinks[0].protocol = :ts6
  end

  setup do
    $uplink = Uplink.new($config.uplinks.first)
  end

  denies_topic.nil
  asserts_topic.kind_of Uplink
  asserts('protocol')   { topic.config.protocol     }.equals :ts6
  asserts('casemapping') { topic.config.casemapping }.equals :rfc1459

  context :parse do
    hookup do
      fp    = File.expand_path('burst.txt', File.dirname(__FILE__))
      burst = File.readlines(fp)
      topic.instance_variable_set(:@recvq, burst)
    end

    asserts('responds to irc_pass')   { topic.respond_to?(:irc_pass,   true) }
    asserts('responds to irc_server') { topic.respond_to?(:irc_server, true) }
    asserts('responds to irc_sid')    { topic.respond_to?(:irc_sid,    true) }
    asserts('responds to irc_uid')    { topic.respond_to?(:irc_uid,    true) }
    asserts('responds to irc_sjoin')  { topic.respond_to?(:irc_sjoin,  true) }
    asserts('responds to irc_ping')   { topic.respond_to?(:irc_ping,   true) }
    asserts('responds to irc_nick')   { topic.respond_to?(:irc_nick,   true) }
    asserts('responds to irc_part')   { topic.respond_to?(:irc_part,   true) }
    asserts('responds to irc_quit')   { topic.respond_to?(:irc_quit,   true) }
    asserts('responds to irc_tmode')  { topic.respond_to?(:irc_tmode,  true) }
    asserts('responds to irc_squit')  { topic.respond_to?(:irc_squit,  true) }

    asserts('users')    { $users.clear;    $users    }.empty
    asserts('channels') { Channel.channels.clear }.empty
    asserts('servers')  { $servers.clear;  $servers  }.empty

    asserts(:burst) { topic.instance_variable_get(:@recvq) }.size 226
    asserts('parses') { topic.send(:parse) }

    asserts('has 10 servers')   { $servers .length == 10 }
    asserts('has 89 users')     { $users   .length == 89 }
    asserts('has 100 channels') { Channel.channels.length == 90 }

    context :servers do
      setup { $servers.values }

      denies_topic.nil
      denies_topic.empty
      asserts(:size) { topic.length }.equals 10

      context :first do
        setup { topic.find { |s| s.sid == '0X0' } }

        denies_topic.nil
        asserts_topic.kind_of Server

        asserts(:sid)        .equals '0X0'
        asserts(:name)       .equals 'test.server.com'
        asserts(:description).equals 'test server'

        context :users do
          setup { topic.users }

          denies_topic.nil
          asserts_topic.empty
        end
      end

      context :second do
        setup { topic.find { |s| s.sid == '0AA' } }

        denies_topic.nil
        asserts_topic.kind_of Server

        asserts(:sid)        .equals '0AA'
        asserts(:name)       .equals 'test.server0AA.com'
        asserts(:description).equals 'server 0AA'

        context :users do
          setup { topic.users }

          denies_topic.nil
          denies_topic.empty
          asserts(:size) { topic.length }.equals 10

          context :first do
            setup { topic.find { |u| u.uid == '0AAAAAAAA' } }

            denies_topic.nil
            asserts_topic.kind_of User

            asserts(:operator?)
            asserts('administrator?') { topic.has_mode?(:administrator) }
            asserts('invisible?')     { topic.has_mode?(:invisible)     }
            asserts('wallop?')        { topic.has_mode?(:wallop)        }

            asserts(:uid)      .equals '0AAAAAAAA'
            asserts(:nickname) .equals 'rakaur'
            asserts(:username) .equals 'rakaur'
            asserts(:hostname) .equals 'malkier.net'
            asserts(:realname) .equals 'Eric Will'
            asserts(:ip)       .equals '69.162.167.45'
            asserts(:timestamp).equals 1307151136
          end
        end
      end

      context :quit do
        setup { $servers['0AI'] }
        asserts_topic.nil
      end
    end

    context :users do
      setup { $users.values }

      denies_topic.empty
      asserts(:size) { topic.length }.equals 89

      context :first do
        setup { topic.find { |u| u.uid == '0AAAAAAAA' } }

        denies_topic.nil
        asserts_topic.kind_of User
        asserts(:operator?)

        asserts(:uid)      .equals '0AAAAAAAA'
        asserts(:nickname) .equals 'rakaur'
        asserts(:username) .equals 'rakaur'
        asserts(:hostname) .equals 'malkier.net'
        asserts(:realname) .equals 'Eric Will'
        asserts(:ip)       .equals '69.162.167.45'
        asserts(:timestamp).equals 1307151136

        asserts('is on #malkier') { topic.is_on?('#malkier') }
        denies('is on #tggpdx')   { topic.is_on?('#tggpdx')  }

        asserts('is an operator on #malkier') do
          topic.has_mode_on_channel?(:operator, '#malkier')
        end

        asserts('is voiced on #malkier') do
          topic.has_mode_on_channel?(:voice, '#malkier')
        end
      end

      context :last do
        setup { $users['0AJAAAAAJ'] }

        asserts(:uid).equals '0AJAAAAAJ'
        asserts(:nickname).equals 'test_nick'
        asserts(:timestamp).equals 1316970148
        asserts('is on #malkier') { topic.is_on?('#malkier') }
      end

      context :quit do
        setup { $users['0AJAAAAAI'] }
        asserts_topic.nil
      end

      context :squit do
        setup { $users['0AIAAAAAJ'] }
        asserts_topic.nil
      end
    end

    context :channels do
      setup { Channel.channels.values }

      denies_topic.empty
      asserts(:size) { topic.length }.equals 90

      context :first do
        setup { topic.find { |c| c.name == '#malkier' } }

        denies_topic.nil
        asserts_topic.kind_of Channel

        asserts(:name).equals '#malkier'
        asserts('is invite only')  { topic.has_mode?(:invite_only) }
        denies('is keyed')         { topic.has_mode?(:keyed)       }
        asserts('is moderated')    { topic.has_mode?(:moderated)   }
        asserts('is no external')  { topic.has_mode?(:no_external) }
        asserts('is secret')       { topic.has_mode?(:secret)      }
        asserts('is topic locked') { topic.has_mode?(:topic_lock)  }
        asserts('is limited')      { topic.has_mode?(:limited)     }
        asserts('limit')           { topic.mode_param(:limited) }.equals "15"

        denies('ts is banned')   { topic.is_banned?('*!invalid@time.stamp')    }
        asserts('dk is banned')  { topic.is_banned?('*!xiphias@khaydarin.net') }
        asserts('jk is execpt')  { topic.is_excepted?('*!justin@othius.com')   }
        asserts('wp is invexed') { topic.is_invexed?('*!nenolod@nenolod.net')  }

        asserts('rakaur is member') { topic.members['0AAAAAAAA'] }
        asserts('member count')     { topic.members.length }.equals 7
      end

      context :squit do
        setup { Channel['#wlzogt'] }
        asserts_topic.nil
      end
    end
  end
end
