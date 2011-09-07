#
# kythera: services for IRC networks
# test/uplink_test.rb: tests the Uplink class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('teststrap', File.dirname(__FILE__))

context :uplink do
  setup do
    $_uplink_block.call
    $uplink = Uplink.new($config.uplinks[0])
  end

  denies(:nil?)

  hookup { topic.instance_variable_set(:@recvq, BURST) }

  context :recvq do
    setup { topic.instance_variable_get(:@recvq) }

    asserts_topic.kind_of Array
    denies_topic.empty
    asserts_topic.size 2
  end
end
