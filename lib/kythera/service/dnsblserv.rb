#
# kythera: services for TSora IRC networks
# lib/kythera/service/dnsblserv.rb: provides DNSBL checking
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Michael Rodriguez <xiphias@khaydarin.net>
# Rights to this code are documented in doc/license.txt
#

%w(kythera resolv).each { |lib| require lib }

# Provides a DNSBL-checking service
class DNSBLService < Service
    # Backwards-incompatible changes
    V_MAJOR = 0

    # Backwards-compatible changes
    V_MINOR = 0

    # Minor changes and bugfixes
    V_PATCH = 1

    # String representation of our version..
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    # Is this service enabled in the configuration?
    #
    # @return [Boolean] true or false
    #
    def self.enabled?
        if $config.respond_to?(:dnsblserv) and $config.dnsblserv
            true
        else
            false
        end
    end

    # Verify our configuration
    #
    # @return [Boolean] true or false
    #
    def self.verify_configuration
        c = $config.dnsblserv

        if not c.blacklists or c.blacklists.empty?
            false
        else
            true
        end
    end

    # Called by the daemon when we connect to the uplink
    #
    # @param [Uplink] Uplink interface to the IRC server
    # @param [Logger] Logger interface for logging
    #
    def initialize(uplink, logger)
        super # Prepare uplink/logger objects

        @config = $config.dnsblserv

        log.info "dnsblserv module loaded (version #{VERSION})"

        # We don't check users while we're bursting
        @bursting = true

        # Listen for user connections
        $eventq.handle(:user_added) { |user| check_user(user) }

        # Enable BL checking after the burst is done
        $eventq.handle(:end_of_burst) { @bursting = false }
    end

    private

    def check_user(user)
        return if @bursting

        # Reverse their IP bits
        m    = Resolv::IPv4::Regex.match(user.ip)
        ip   = "#{m[4]}.#{m[3]}.#{m[2]}.#{m[1]}"

        # Go through each list and check the IP
        @config.blacklists.each do |name, url|
            addr = "#{ip}.#{url}"
            log.debug "dnsbl checking: #{name} -> #{user.ip}"

            begin
                Resolv.getaddress(addr)
            rescue Resolv::ResolvError
                next
            else
                log.debug "dnsbl positive: #{name} <- #{user.ip}"
                # XXX - set the kline!

                # We don't need to check other lists since it's positive
                break
            end
        end
    end
end

# This is extended into $config
module DNSBLService::Configuration
    # This will be $config.dnsblserv
    attr_reader :dnsblserv

    # Implements the 'dnsbl_service' portion of the config
    def dnsbl_service(&block)
        return if @dnsblserv

        @dnsblserv = OpenStruct.new
        @dnsblserv.extend(DNSBLService::Configuration::Methods)

        @dnsblserv.instance_eval(&block)
    end
end

# Contains the methods that do the config parsing
module DNSBLService::Configuration::Methods
    # Adds methods to the parser from an arbitrary module
    #
    # @param [Module] mod the module containing methods to add
    #
    def use(mod)
        self.extend(mod)
    end

    private

    def blacklist(name, url)
        self.blacklists ||= {}
        self.blacklists[name] = url
    end
end
