#
# kythera: services for IRC networks
# test/teststrap.rb: required by all tests
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

$LOAD_PATH.unshift File.expand_path('../',    File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'rubygems'
require 'kythera'
require 'riot'
#require 'riot/rr'

# For all tests
$config   = nil
$log      = Log::NilLogger.instance
$eventq   = EventQueue.new
$users    = IRCHash.new
$channels = IRCHash.new
$servers  = IRCHash.new

# These are defined here for easy use in setup blocks
$_daemon_block = proc do
  next if $config and $config.me

  configure_test do
    daemon do
      name              'kythera.test'
      description       'kythera unit tester'
      admin             :rakaur, 'rakaur@malkier.net'
      logging           :debug
      unsafe_extensions :die
      reconnect_time    10
      verify_emails     false
      mailer            '/usr/sbin/sendmail'
    end
  end
end

$_uplink_block = proc do
  next if $config and $config.uplinks and $config.uplinks[0]

  configure_test do
    uplink '127.0.0.1', 6667 do
      priority         1
      name             'test.server.com'
      sid              '0X0'
      send_password    :unit_tester
      receive_password :unit_tester
      network          :testing
      protocol         :ts6
      casemapping      :rfc1459
    end
  end
end
