#
# kythera: services for IRC networks
# test/protocol/unreal_test.rb: tests the Protocol::Unreal module
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('../teststrap', File.dirname(__FILE__))

context :unreal do
  setup do
    $_daemon_block.call
    $_uplink_block.call
    $uplink = Uplink.new($config.uplinks[0])
  end

  hookup do
    require 'kythera/protocol/unreal'
    $uplink.config.protocol = :unreal
  end

  denies_topic.nil
  asserts_topic.kind_of Uplink
  asserts('protocol') { topic.config.protocol }.equals :unreal

  context :parse do
    hookup do
      fp    = File.expand_path('unreal_burst.txt', File.dirname(__FILE__))
      burst = File.readlines(fp)
      topic.instance_variable_set(:@recvq, burst)
    end

    $users.clear
    $channels.clear
    $servers.clear

    asserts('responds to irc_pass')   { topic.respond_to?(:irc_pass,   true) }
    asserts('responds to irc_server') { topic.respond_to?(:irc_server, true) }
    asserts('responds to irc_nick')   { topic.respond_to?(:irc_nick,   true) }
    asserts('responds to irc_sjoin')  { topic.respond_to?(:irc_sjoin,  true) }

    asserts('users')    { $users.clear;    $users    }.empty
    asserts('channels') { $channels.clear; $channels }.empty
    asserts('servers')  { $servers.clear;  $servers  }.empty

    asserts(:burst) { topic.instance_variable_get(:@recvq) }.size 224
    asserts('parses') { topic.send(:parse) }

    asserts('has 11 servers')   { $servers .length == 11  }
    asserts('has 100 users')    { $users   .length == 100 }
    asserts('has 100 channels') { $channels.length == 100 }

    context :servers do
      setup { $servers.values }

      denies_topic.nil
      denies_topic.empty
      asserts_topic.size 11

      context :first do
        setup { topic.first }

        denies_topic.nil
        asserts_topic.kind_of Server

        asserts(:name)       .equals 'test.server.com'
        asserts(:description).equals 'test server'

        context :users do
          setup { topic.users }

          denies_topic.nil
          asserts_topic.empty
        end
      end

      context :second do
        setup { topic[1] }

        denies_topic.nil
        asserts_topic.kind_of Server

        asserts(:name)       .equals 'test.server1.com'
        asserts(:description).equals 'server 1'

        context :users do
          setup { topic.users }

          denies_topic.nil
          denies_topic.empty
          asserts_topic.size 10

          context :second do
            setup { topic.first }

            denies_topic.nil
            asserts_topic.kind_of User
            asserts(:operator?)

            asserts(:nickname) .equals 'rakaur'
            asserts(:username) .equals 'rakaur'
            asserts(:hostname) .equals 'malkier.net'
            asserts(:realname) .equals 'Eric Will'
            asserts(:timestamp).equals 1307151136
            asserts(:vhost)    .equals 'malkier.net'
            asserts(:cloakhost).equals 'malkier.net'
          end
        end
      end
    end

    context :users do
      setup { $users.values }

      denies_topic.empty
      asserts_topic.size 100

      context :first do
        setup { topic.first }

        denies_topic.nil
        asserts_topic.kind_of User
        asserts(:operator?)

        asserts(:nickname) .equals 'rakaur'
        asserts(:username) .equals 'rakaur'
        asserts(:hostname) .equals 'malkier.net'
        asserts(:realname) .equals 'Eric Will'
        asserts(:timestamp).equals 1307151136
        asserts(:vhost)    .equals 'malkier.net'
        asserts(:cloakhost).equals 'malkier.net'
      end
    end
  end
end
