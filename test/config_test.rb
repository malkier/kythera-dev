# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/config_test.rb: tests the configuration
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require File.expand_path('teststrap', File.dirname(__FILE__))

context :configuration do
  setup do
    configure_test do
    end

    $config
  end

  denies_topic.nil

  context :daemon do
   setup do
     $_daemon_block.call
     $_logger_setup.call
     $config.me
   end

   denies_topic.nil
   asserts(:name)             .equals 'kythera.test'
   asserts(:description)      .equals 'kythera unit tester'
   asserts(:admin_name)       .equals 'rakaur'
   asserts(:admin_email)      .equals 'rakaur@malkier.net'
   asserts(:logging)          .equals :debug
   asserts(:unsafe_extensions).equals :die
   asserts(:reconnect_time)   .equals 10
   asserts(:mailer)           .equals '/usr/sbin/sendmail'

   denies(:verify_emails)
  end

  context :uplinks do
   setup do
     $_uplink_block.call
     $config.uplinks
   end

   denies_topic.nil
   denies_topic.empty

   asserts_topic.kind_of Array
   asserts_topic.size 1

   context :element do
     setup { $config.uplinks.first }

     denies_topic.nil
     asserts(:host)            .equals '127.0.0.1'
     asserts(:port)            .equals 6667
     asserts(:name)            .equals 'test.server.com'
     asserts(:priority)        .equals 1
     asserts(:sid)             .equals '0XX'
     asserts(:send_password)   .equals 'unit_tester'
     asserts(:receive_password).equals 'unit_tester'
     asserts(:network)         .equals 'testing'
     asserts(:max_modes)       .equals 3
   end
  end
end
