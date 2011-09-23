#
# kythera: services for IRC networks
# test/protocol/ts6_test.rb: tests the Protocol::TS6 module
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('../../teststrap', File.dirname(__FILE__))

context :ts6 do
  setup do
    $_daemon_block.call
    $_uplink_block.call
    $uplink = Uplink.new($config.uplinks[0])
  end

  hookup do
    require 'kythera/protocol/ts6'
    $uplink.config.protocol = :ts6
  end

  denies_topic.nil
  asserts_topic.kind_of Uplink
  asserts('protocol') { topic.config.protocol }.equals :ts6

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

    asserts('users')    { $users.clear;    $users    }.empty
    asserts('channels') { $channels.clear; $channels }.empty
    asserts('servers')  { $servers.clear;  $servers  }.empty

    asserts(:burst) { topic.instance_variable_get(:@recvq) }.size 215
    asserts('parses') { topic.send(:parse) }

    asserts('has 11 servers')   { $servers .length == 11  }
    asserts('has 100 users')    { $users   .length == 100 }
    asserts('has 100 channels') { $channels.length == 100 }

    context :servers do
      setup { $servers.values }

      denies_topic.nil
      denies_topic.empty
      asserts(:size) { topic.length }.equals 11

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
    end

    context :users do
      setup { $users.values }

      denies_topic.empty
      asserts(:size) { topic.length }.equals 100

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

        asserts('is an operator on #malkier') do
          topic.has_mode_on_channel?(:operator, '#malkier')
        end

        asserts('is voiced on #malkier') do
          topic.has_mode_on_channel?(:voice, '#malkier')
        end
      end
    end

    context :channels do
      setup { $channels.values }

      denies_topic.empty
      asserts(:size) { topic.length }.equals 100

      context :first do
        setup { topic.find { |c| c.name == '#malkier' } }

        denies_topic.nil
        asserts_topic.kind_of Channel

        asserts(:name).equals '#malkier'
        asserts('is invite only')  { topic.has_mode?(:invite_only) }
        asserts('is moderated')    { topic.has_mode?(:moderated)   }
        asserts('is no external')  { topic.has_mode?(:no_external) }
        asserts('is topic locked') { topic.has_mode?(:topic_lock)  }
        asserts('is limited')      { topic.has_mode?(:limited)     }
        asserts('limit')           { topic.mode_param(:limited) }.equals "15"

        asserts('rakaur is member') { topic.members['0AAAAAAAA'] }
        asserts('member count')     { topic.members.length }.equals 6
      end
    end
  end
end
