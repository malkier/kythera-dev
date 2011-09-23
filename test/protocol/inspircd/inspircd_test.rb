#
# kythera: services for IRC networks
# test/protocol/ts6_test.rb: tests the Protocol::TS6 module
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('../../teststrap', File.dirname(__FILE__))

context :inspircd do
  setup do
    $_daemon_block.call
    $_uplink_block.call
    $uplink = Uplink.new($config.uplinks[0])
  end

  hookup do
    require 'kythera/protocol/inspircd'
    $uplink.config.protocol = :inspircd
  end

  denies_topic.nil
  asserts_topic.kind_of Uplink
  asserts('protocol') { topic.config.protocol }.equals :inspircd

  context :parse do
    hookup do
      fp    = File.expand_path('burst.txt', File.dirname(__FILE__))
      burst = File.readlines(fp)
      topic.instance_variable_set(:@recvq, burst)
    end

    asserts('responds to irc_capab')  { topic.respond_to?(:irc_capab,  true) }
    asserts('responds to irc_server') { topic.respond_to?(:irc_server, true) }
    asserts('responds to irc_uid')    { topic.respond_to?(:irc_uid,    true) }
    asserts('responds to irc_fjoin')  { topic.respond_to?(:irc_fjoin,  true) }

    asserts('users')    { $users.clear;    $users    }.empty
    asserts('channels') { $channels.clear; $channels }.empty
    asserts('servers')  { $servers.clear;  $servers  }.empty

    asserts(:burst) { topic.instance_variable_get(:@recvq) }.size 219
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
        asserts('is halfop on #malkier') do
          topic.has_mode_on_channel?(:halfop, '#malkier')
        end
        asserts('is owner on #malkier') do
          topic.has_mode_on_channel?(:owner, '#malkier')
        end
        asserts('is protected on #malkier') do
          topic.has_mode_on_channel?(:protected, '#malkier')
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
        asserts('is flood protected') { topic.has_mode?(:flood_protection) }
        asserts('is keyed')           { topic.has_mode?(:keyed)            }
        asserts('is limited ')        { topic.has_mode?(:limited)          }
        asserts('is allow invite')    { topic.has_mode?(:allow_invite)     }
        asserts('is block caps')      { topic.has_mode?(:block_caps)       }
        asserts('is block color')     { topic.has_mode?(:block_color)      }
        asserts('is no ctcp')         { topic.has_mode?(:no_ctcp)          }
        asserts('is auditorium')      { topic.has_mode?(:auditorium)       }
        asserts('is SSL only')        { topic.has_mode?(:ssl_only)         }

        asserts('flood') { topic.mode_param(:flood_protection) }.equals "10:5"
        asserts('key')   { topic.key }.equals 'partypants'
        asserts('limit') { topic.mode_param(:limited) }.equals "15"

        asserts('rakaur is member') { topic.members['0AAAAAAAA'] }
        asserts('member count')     { topic.members.length }.equals 6
      end
    end
  end
end
