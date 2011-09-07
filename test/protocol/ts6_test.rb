#
# kythera: services for IRC networks
# test/protocol/ts6_test.rb: tests the Protocol::TS6 module
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('../teststrap', File.dirname(__FILE__))

context :ts6 do
  setup do
    $_daemon_block.call
    $_uplink_block.call
    $uplink = Uplink.new($config.uplinks[0])
  end

  denies_topic.nil
  asserts_topic.kind_of Uplink

  context :parse do
    hookup do
      fp    = File.expand_path('ts6_burst.txt', File.dirname(__FILE__))
      burst = File.readlines(fp)
      topic.instance_variable_set(:@recvq, burst)
    end

    asserts('responds to irc_pass')   { topic.respond_to?(:irc_pass, true)   }
    denies('responds to irc_capab')   { topic.respond_to?(:irc_capab, true)  }
    asserts('responds to irc_server') { topic.respond_to?(:irc_server, true) }
    asserts('responds to irc_sid')    { topic.respond_to?(:irc_sid, true)    }
    asserts('responds to irc_uid')    { topic.respond_to?(:irc_uid, true)    }
    asserts('responds to irc_join')   { topic.respond_to?(:irc_sjoin, true)  }

    asserts(:burst) { topic.instance_variable_get(:@recvq) }.size 215
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
        setup { topic[1] }

        denies_topic.nil
        asserts_topic.kind_of Server

        asserts(:sid)        .equals '0AA'
        asserts(:name)       .equals 'test.server0AA.com'
        asserts(:description).equals 'server 0AA'

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
      asserts_topic.size 100

      context :first do
        setup { topic.first }

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
