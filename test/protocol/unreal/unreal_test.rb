# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/protocol/unreal_test.rb: tests the Protocol::Unreal module
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require File.expand_path('../../teststrap', File.dirname(__FILE__))

context :unreal do
  hookup do
    $_daemon_block.call
    $_uplink_block.call
    $_logger_setup.call

    require 'kythera/protocol/unreal'
    $config.uplinks[0].protocol = :unreal
  end

  setup do
    $uplink = Uplink.new($config.uplinks.first)
  end

  denies_topic.nil
  asserts_topic.kind_of Uplink
  asserts('protocol')   { topic.config.protocol     }.equals :unreal
  asserts('casemapping') { topic.config.casemapping }.equals :ascii

  context :parse do
    hookup do
      fp    = File.expand_path('burst.txt', File.dirname(__FILE__))
      burst = File.readlines(fp)
      topic.instance_variable_set(:@recvq, burst)
    end

    asserts('responds to irc_pass')   { topic.respond_to?(:irc_pass,   true) }
    asserts('responds to irc_server') { topic.respond_to?(:irc_server, true) }
    asserts('responds to irc_nick')   { topic.respond_to?(:irc_nick,   true) }
    asserts('responds to irc_sjoin')  { topic.respond_to?(:irc_sjoin,  true) }
    asserts('responds to irc_ping')   { topic.respond_to?(:irc_ping,   true) }
    asserts('responds to irc_part')   { topic.respond_to?(:irc_part,   true) }
    asserts('responds to irc_quit')   { topic.respond_to?(:irc_quit,   true) }
    asserts('responds to irc_mode')   { topic.respond_to?(:irc_mode,   true) }
    asserts('responds to irc_squit')  { topic.respond_to?(:irc_squit,  true) }

    asserts('users')    { $users.clear;    $users    }.empty
    asserts('channels') { $channels.clear; $channels }.empty
    asserts('servers')  { $servers.clear;  $servers  }.empty

    asserts(:burst) { topic.instance_variable_get(:@recvq) }.size 230
    asserts('parses') { topic.send(:parse) }

    asserts('has 10 servers')   { $servers .length == 10  }
    asserts('has 89 users')     { $users   .length == 89  }
    asserts('has 100 channels') { $channels.length == 100 }

    context :servers do
      setup { $servers.values }

      denies_topic.nil
      denies_topic.empty
      asserts(:size) { topic.length }.equals 10

      context :first do
        setup { $servers['test.server.com'] }

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
        setup { $servers['test.server1.com'] }

        denies_topic.nil
        asserts_topic.kind_of Server

        asserts(:name)       .equals 'test.server1.com'
        asserts(:description).equals 'server 1'

        context :users do
          setup { topic.users }

          denies_topic.nil
          denies_topic.empty
          asserts(:size) { topic.length }.equals 10

          context :first do
            setup { topic.find { |s| s.nickname == 'rakaur' } }

            denies_topic.nil
            asserts_topic.kind_of User
            asserts(:operator?)

            asserts(:nickname) .equals 'rakaur'
            asserts(:username) .equals 'rakaur'
            asserts(:hostname) .equals 'malkier.net'
            asserts(:realname) .equals 'Eric Will'
            asserts(:timestamp).equals 1307151136
            asserts(:vhost)    .equals 'malkier.net'
          end
        end
      end

      context :quit do
        setup { $servers['test.server8.com'] }
        asserts_topic.nil
      end
    end

    context :users do
      setup { $users.values }

      denies_topic.empty
      asserts(:size) { topic.length }.equals 89

      context :first do
        setup { topic.find { |u| u.nickname == 'rakaur' } }

        denies_topic.nil
        asserts_topic.kind_of User

        asserts(:operator?)
        asserts('co_admin?')        { topic.has_mode?(:co_admin)         }
        asserts('deaf?')            { topic.has_mode?(:deaf)             }
        asserts('censored?')        { topic.has_mode?(:censored)         }
        asserts('hidden_operator?') { topic.has_mode?(:hidden_operator)  }
        asserts('helper?')          { topic.has_mode?(:helper)           }
        asserts('invisible?')       { topic.has_mode?(:invisible)        }
        asserts('net_admin?')       { topic.has_mode?(:net_admin)        }
        asserts('invulnerable?')    { topic.has_mode?(:invulnerable)     }
        asserts('registered?')      { topic.has_mode?(:registered)       }
        asserts('no_ctcp?')         { topic.has_mode?(:no_ctcp)          }
        asserts('webtv?')           { topic.has_mode?(:webtv)            }
        asserts('see_whois?')       { topic.has_mode?(:see_whois)        }
        denies('service?')          { topic.has_mode?(:service)          }

        asserts(:nickname) .equals 'rakaur'
        asserts(:username) .equals 'rakaur'
        asserts(:hostname) .equals 'malkier.net'
        asserts(:realname) .equals 'Eric Will'
        asserts(:timestamp).equals 1307151136
        asserts(:vhost)    .equals 'malkier.net'

        asserts('is on #malkier') { topic.is_on?('#malkier') }
        denies('is on #6')        { topic.is_on?('#6')       }

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
        asserts('is admin on #malkier') do
          topic.has_mode_on_channel?(:admin, '#malkier')
        end
      end

      context :last do
        setup { $users['test_nick'] }

        asserts(:nickname).equals 'test_nick'
        asserts(:timestamp).equals 1316970148
        asserts('is on #malkier') { topic.is_on?('#malkier') }
      end

      context :quit do
        setup { $users['n81'] }
        asserts_topic.nil
      end

      context :squit do
        setup { $users['n79'] }
        asserts_topic.nil
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
        asserts('is censored')        { topic.has_mode?(:censored)         }
        asserts('is ircops only')     { topic.has_mode?(:ircops_only)      }
        asserts('is secret')          { topic.has_mode?(:secret)           }
        asserts('is topic locked')    { topic.has_mode?(:topic_lock)       }
        asserts('is auditorium')      { topic.has_mode?(:auditorium)       }
        asserts('is no invite')       { topic.has_mode?(:no_invite)        }
        asserts('is SSL only')        { topic.has_mode?(:ssl_only)         }
        asserts('is limited')         { topic.has_mode?(:limited)          }
        asserts('is no_ansi')         { topic.has_mode?(:no_ansi)          }

        asserts('flood') { topic.mode_param(:flood_protection) }.equals "10:5"
        asserts('key')   { topic.mode_param(:keyed) }.equals 'partypants'
        asserts('limit') { topic.mode_param(:limited) }.equals "15"

        denies('ts is banned')   { topic.is_banned?('*!invalid@time.stamp')    }
        asserts('dk is banned')  { topic.is_banned?('*!xiphias@khaydarin.net') }
        asserts('jk is execpt')  { topic.is_excepted?('*!justin@othius.com')   }
        asserts('wp is invexed') { topic.is_invexed?('*!nenolod@nenolod.net')  }

        asserts('rakaur is member') { topic.members['rakaur'] }
        asserts('member count')     { topic.members.length }.equals 44
      end

      context :squit do
        setup { $channels['#79'] }
        denies_topic.nil
        asserts('channel #79 member count') { topic.members.length }.equals 41
      end
    end
  end
end
