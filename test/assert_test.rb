#
# kythera: services for IRC networks
# test/config_test.rb: tests the configuration
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require File.expand_path('teststrap', File.dirname(__FILE__))

module AssertTest
  class TestClass
  end
end

context :assert do
  setup do
    $_daemon_block.call
    $config.me.logging = :debug
  end

  context :blackmagic do
    context 'string-based argument mismatch' do
      asserts('variable name') do
        hash = []
        assert { 'hash' }
      end.raises(ArgumentError)

      asserts('class mame') do
        hash = []
        assert { 'Hash' }
      end.raises(ArgumentError)
    end

    context 'array-based argument mismatch' do
      asserts('with Symbol elements') do
        hash   = []
        array  = {}
        assert { [:hash, :array] }
      end.raises(ArgumentError)

      asserts('with String elements') do
        hash   = []
        array  = {}
        assert { ['hash', 'Array'] }
      end.raises(ArgumentError)

      asserts('with Class elements') do
        hash   = []
        array  = {}
        assert { [Hash, Array] }
      end.raises(ArgumentError)
    end

    context 'hash-based argument mismatch' do
      asserts('with Symbol keys and elements') do
        a = []
        b = {}
        assert { {:a => :hash, :b => :Array} }
      end.raises(ArgumentError)

      asserts('with String keys and elements') do
        a = []
        b = {}
        assert { {'a' => 'hash', 'b' => 'Array'} }
      end.raises(ArgumentError)

      asserts('with mixed keys and Class elements') do
        a = []
        b = {}
        assert { {'a' => Hash, :b => Array} }
      end.raises(ArgumentError)
    end

    context 'string-based argument match' do
      asserts('variable name') do
        hash = {}
        assert { 'hash' }
        true
      end

      asserts('class mame') do
        hash = {}
        assert { 'Hash' }
        true
      end
    end

    context 'array-based argument match' do
      asserts('with Symbol elements') do
        hash   = {}
        array  = []
        assert { [:hash, :array] }
        true
      end

      asserts('with String elements') do
        hash   = {}
        array  = []
        assert { ['hash', 'Array'] }
        true
      end

      asserts('with Class elements') do
        hash   = {}
        array  = []
        assert { [Hash, Array] }
        true
      end
    end

    context 'hash-based argument match' do
      asserts('with Symbol keys and elements') do
        a = {}
        b = []
        assert { {:a => :hash, :b => :Array} }
        true
      end

      asserts('with String keys and elements') do
        a = {}
        b = []
        assert { {'a' => 'hash', 'b' => 'Array'} }
        true
      end

      asserts('with mixed keys and Class elements') do
        a = {}
        b = []
        assert { {'a' => Hash, :b => Array} }
        true
      end
    end
  end
end
