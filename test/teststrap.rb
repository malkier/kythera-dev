# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/teststrap.rb: required by all tests
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

$LOAD_PATH.unshift File.expand_path('../',    File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'rubygems'
require 'kythera'
require 'riot'

# Set up Riot a little more explicitly
Riot.verbose # use verbose error reporting (dump a callstack on errors)
Riot.alone!  # require riot to be run manually, so we can do post-test cleanup

# Require sequel, delete any old test db, and create the connection here. This
# is done in a BEGIN block so it executes before the requires above.
BEGIN {
  require 'sequel'
  File.delete('db/test.db') rescue nil
  $db = Sequel.sqlite('db/test.db')

  # Run the migrations here, and then the models will have them to load.
  Sequel.extension :migration
  Sequel::Migrator.run Sequel::Model.db, 'db/migrations'
}

# Run the tests after everything has been loaded up (variables defined etc), and
# delete the test db afterwards (but only if KEEP_TEST_DB is not set).
END {
  status = Riot.run.success?

  unless ENV['KEEP_TEST_DB'] == 'yes'
    File.delete('db/test.db') rescue nil
  end

  exit(status)
}

# For all tests
$config       = nil
Log.logger    = Log::NilLogger.instance
Riot.reporter = Riot::VerboseStoryReporter

# These are defined here for easy use in setup blocks
$_daemon_block = proc do
  next if $config and $config.me

  configure_test do
    daemon do
      name              'kythera.test'
      description       'kythera unit tester'
      admin             :rakaur, 'rakaur@malkier.net'
      unsafe_extensions :die
      reconnect_time    10
      verify_emails     false
      mailer            '/usr/sbin/sendmail'
    end
  end
end

$_uplink_block = proc do
  next if $config and $config.uplinks and $config.uplinks.first

  configure_test do
    uplink '127.0.0.1', 6667 do
      priority         1
      name             'test.server.com'
      sid              '0XX'
      send_password    :unit_tester
      receive_password :unit_tester
      network          :testing
    end
  end
end

$_logger_setup = proc do
  if $config and $config.me
    $config.me.logging = :debug
  end

  $logger = Log::NilLogger.instance
end
