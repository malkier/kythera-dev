# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/dnsblserv.rb: provides DNSBL checking
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Michael Rodriguez <xiphias@khaydarin.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

require 'resolv'

# Provides a DNSBL-checking service
class DNSBLService < Service
    # Our name (for use in the config, etc)
    NAME = :dnsblserv

    # Backwards-incompatible changes
    V_MAJOR = 1

    # Backwards-compatible changes
    V_MINOR = 0

    # Minor changes and bugfixes
    V_PATCH = 2

    # String representation of our version..
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    # Verify our configuration
    #
    # @return [True, False]
    #
    def self.verify_configuration
        c = $config.dnsblserv

        if not c or not c.blacklists or c.blacklists.empty?
            false
        else
            true
        end
    end

    # Called by the daemon when we connect to the uplink
    def initialize
        # Shortcut to our configuration info
        @config = $config.dnsblserv

        # If a delay isn't provided in the config, assume it's zero
        @config.delay ||= 0

        # Number of users currently waiting to be checked
        @needs_checking = 0

        $log.debug "DNSBL service loaded (version #{VERSION})"

        # Listen for user connections
        $eventq.handle(:user_added) { |user| queue_user(user) }
    end

    private

    # Add the user to our to-be-checked queue
    def queue_user(user)
        return $state.bursting

        # Calculate our time delay for this check
        time = (@needs_checking * @config.delay) + @config.delay

        Timer.after(time) { check_user(user) }

        @needs_checking += 1
    end

    # Does the actual DNSBL lookup
    def check_user(user)
        return if $state.bursting
        return if user.operator? # Don't scan opers

        # Reverse their IP bits
        m  = Resolv::IPv4::Regex.match(user.ip)
        ip = "#{m[4]}.#{m[3]}.#{m[2]}.#{m[1]}"

        # Go through each list and check the IP
        @config.blacklists.each do |address|
            check_addr = "#{ip}.#{address}"

            $log.debug "dnsbl checking: #{check_addr}"

            begin
                Resolv.getaddress(check_addr)
            rescue Resolv::ResolvError
                next
            else
                $log.info "dnsbl positive: #{check_addr}"
                # XXX - set the kline!

                # We don't need to check other lists since it's positive
                break
            end
        end

        @needs_checking -= 1
    end
end

# Contains the methods that do the config parsing
module DNSBLService::Configuration
    # Adds methods to the parser from an arbitrary module
    #
    # @param [Module] mod the module containing methods to add
    #
    def use(mod)
        self.extend(mod)
    end

    private

    def blacklist(*addresses)
        self.blacklists ||= []
        self.blacklists.concat(addresses)
    end

    def delay(seconds)
        self.delay = seconds
    end
end
