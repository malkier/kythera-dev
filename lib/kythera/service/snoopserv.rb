# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/snoopserv.rb: reports on services activity
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# This service reports various services activity to a designated channel
class SnoopService < Service
    # Our name (for use in the config, etc)
    NAME = :snoopserv

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
    # @return [True, False]
    #
    def self.verify_configuration(c)
        unless c and c.nickname and c.username and c.hostname and
               c.realname and c.channel
            false
        else
            true
        end
    end

    # This is called during a rehash to update our configuration
    # We should check it over for changes to implement, etc. - XXX
    #
    def config=(config)
        # Did our channel change?
        if @config.channel
            if config.channel != @config.channel
                part(@user.key, @config.channel)
                join(@user.key, config.channel) if config.channel
            end
        elsif config.channel
            join(@user.uid, config.channel)
        end

        @config = config
        $log.debug 'snoopserv: configuration updated!'
    end

    # This is all we do for now :)
    def initialize(config)
        @config = config

        $log.info "Snoop service loaded (version #{VERSION})"

        # Introduce our user in the burst
        $eventq.handle(:start_of_burst) do
            modes = [:deaf, :invulnerable, :service]

            # Introduce our client to the network
            @user = introduce_user(@config.nickname, @config.username,
                                   @config.hostname, @config.realname, modes)
        end

        # Join our configuration channel
        $eventq.handle(:end_of_burst) { join(@user.key, @config.channel) }

        # Listen for snoops
        $eventq.handle(:snoop) do |service, command, str|
            snoop = "#{str} [#{service}->#{command}]"
            privmsg(@user.key, @config.channel, snoop)
        end

        # When we're exiting, quit our user
        $eventq.handle(:exit) { |reason| quit(@user.key, reason) if @user }
    end
end

# Contains the methods that do the config parsing
module SnoopService::Configuration
    # Adds methods to the parser from an arbitrary module
    #
    # @param [Module] mod the module containing methods to add
    #
    def use(mod)
        self.extend(mod)
    end

    private

    def nickname(nick)
        self.nickname = nick.to_s
    end

    def username(user)
        self.username = user.to_s
    end

    def hostname(host)
        self.hostname = host.to_s
    end

    def realname(real)
        self.realname = real.to_s
    end

    def channel(channel)
        self.channel = channel
    end
end
