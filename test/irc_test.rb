#
# kythera: services for IRC networks
# test/uplink_test.rb: tests the Uplink class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('teststrap', File.dirname(__FILE__))

context :irc do
  setup do
    $_uplink_block.call
    $uplink = Uplink.new($config.uplinks[0])
  end

  hookup { topic.instance_variable_set(:@recvq, BURST) }

  asserts_topic.kind_of Uplink
  asserts('responds to irc_pass') { topic.respond_to?(:irc_pass, true) }
  asserts('responds to irc_uid') { topic.respond_to?(:irc_uid, true) }
  asserts('parses') { topic.send :parse }

  context :users do
    setup { $users.values }

    asserts_topic.size 1

    context :first do
      setup { topic.first }

      asserts_topic.kind_of User
      asserts(:operator?)

      asserts(:uid)      .equals '0XXAAAAAE'
      asserts(:nickname) .equals 'rakaur'
      asserts(:username) .equals 'rakaur'
      asserts(:hostname) .equals 'malkier.net'
      asserts(:realname) .equals 'Eric Will'
      asserts(:ip)       .equals '69.162.167.45'
      asserts(:timestamp).equals 1307151136
    end
  end

  asserts('has one server') { $servers.length == 1 }
  asserts('has one user')   { $users.length == 1 }
end
