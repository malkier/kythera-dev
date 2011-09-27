# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
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

  denies_topic.nil

  context :recvq do
    hookup do
      fp    = File.expand_path('protocol/ts6/burst.txt', File.dirname(__FILE__))
      burst = File.readlines(fp)
      topic.instance_variable_set(:@recvq, burst)
    end

    setup { topic.instance_variable_get(:@recvq) }

    asserts_topic.kind_of Array
    denies_topic.empty
    asserts_topic.size 226
  end
end
