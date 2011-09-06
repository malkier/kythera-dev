#
# kythera: services for IRC networks
# test/config_test.rb: tests the configuration
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'teststrap'

context :configuration do
    setup do
        configure_test do
        end

        $config
    end

    denies(:nil?)

    context :daemon do
       setup do
           configure_test do
               daemon do
                   name 'kythera.test'
                   description 'kythera unit tester'
                   admin :rakaur, 'rakaur@malkier.net'
                   logging :none
                   unsafe_extensions :die
                   reconnect_time 10
                   verify_emails false
                   mailer '/usr/sbin/sendmail'
               end
           end

           $config.me
       end

       denies(:nil?)
       asserts(:name).equals 'kythera.test'
       asserts(:description).equals 'kythera unit tester'
       asserts(:admin_name).equals 'rakaur'
       asserts(:admin_email).equals 'rakaur@malkier.net'
       asserts(:logging).equals :none
       asserts(:unsafe_extensions).equals :die
       asserts(:reconnect_time).equals 10
       denies(:verify_emails)
       asserts(:mailer).equals '/usr/sbin/sendmail'
    end

    context :uplinks do
       setup do
           configure_test do
               uplink 'unit.tester.uplink', 6667 do
                   priority 1
                   sid '0X0'
                   send_password :unit_tester
                   receive_password :unit_tester
                   network :testing
                   protocol :ts6
                   casemapping :rfc1459
               end
           end

           $config.uplinks
       end

       denies(:nil?)
       denies(:empty?)

       asserts_topic.kind_of Array
       asserts(:length).equals 1

       context 'first uplink' do
           setup { $config.uplinks.first }

           denies(:nil?)
           asserts(:host).equals 'unit.tester.uplink'
           asserts(:port).equals 6667
           asserts(:priority).equals 1
           asserts(:sid).equals '0X0'
           asserts(:send_password).equals 'unit_tester'
           asserts(:receive_password).equals 'unit_tester'
           asserts(:network).equals 'testing'
           asserts(:protocol).equals :ts6
           asserts(:casemapping).equals :rfc1459
       end
    end
end
