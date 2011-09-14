#
# kythera: services for IRC networks
# lib/kythera/service/shrike.rb: implements shrike's X
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

require 'kythera/service/shrike/commands'
require 'kythera/service/shrike/configuration'

# This service is designed to implement the functionality of Shrike IRC Services
class ShrikeService < Service
    # Our name (for use in the config, etc)
    NAME = :shrike

    # For backwards-incompatible changes
    V_MAJOR = 0

    # For backwards-compatible changes
    V_MINOR = 1

    # For minor changes and bugfixes
    V_PATCH = 0

    # A String representation of the version number
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    # Our User object is visible for the Service API
    attr_reader :user

    # Verify our configuration
    #
    # @return [Boolean] true or false
    #
    def self.verify_configuration
        c = $config.shrike

        unless c and c.nickname and c.username and c.hostname and c.realname
            false
        else
            true
        end
    end

    # This is all we do for now :)
    #
    # @param [Uplink] uplink the interface to the IRC server
    #
    def initialize(uplink)
        super # Prepare the uplink object

        @config = $config.shrike

        $log.debug "Shrike service loaded (version #{VERSION})"

        # Introduce our user in the burst
        $eventq.handle(:start_of_burst) do
            if @uplink.config.protocol == :ts6
                modes = 'oD'
            else
                modes = 'o'
            end

            # Introduce our client to the network
            @user = @uplink.introduce_user(@config.nickname, @config.username,
                                           @config.hostname, @config.realname,
                                           modes)
        end

        # Join our configuration channel
        $eventq.handle(:end_of_burst) do
            @uplink.join(@user, @config.channel) if @config.channel
        end
    end

    public

    # Determines if someone is an SRA
    #
    # @param [String] nickname person to check
    # @return [Boolean] true or false
    #
    def is_sra?(nickname)
        @config.sras.include?(nickname)
    end

    # Called by the protocol module to handle commands sent to us
    def irc_privmsg(user, params)
        cmd = params.delete_at(0)
        meth = "do_#{cmd}".downcase.to_sym

        if self.respond_to?(meth, true)
            self.send(meth, user, params)
        else
            @uplink.notice(@user, user, "Invalid command: \2#{cmd}\2")
        end
    end
end
