# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/userserv.rb: implements the user service
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

require 'kythera/service/userserv/commands'
require 'kythera/service/userserv/configuration'

# Provides services for registering accounts
class UserService < Service
    # Our name (for use in the config, etc)
    NAME = :userserv

    # Backwards-incompatible changes
    V_MAJOR = 0

    # Backwards-compatible changes
    V_MINOR = 1

    # Minor changes and bugfixes
    V_PATCH = 0

    # String representation of our version..
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    # Our User object is visible for the Service API
    attr_reader :user

    # Verify our configuration
    #
    # @return [True, False]
    #
    def self.verify_configuration(c)
        unless c and c.nickname and c.username and c.hostname and c.realname
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
        $log.debug 'userserv: configuration updated!'
    end

    # Instantiate the user service
    def initialize(config)
        @config = config

        $log.info "User service loaded (version #{VERSION})"

        # Introduce our user in the burst
        $eventq.handle(:start_of_burst) do
            modes = [:deaf,     :hidden_operator, :invulnerable,
                     :operator, :service]

            # Introduce our client to the network
            @user = introduce_user(@config.nickname, @config.username,
                                   @config.hostname, @config.realname, modes)
        end

        # Join our configuration channel
        $eventq.handle(:end_of_burst) do
            join(@user.key, @config.channel) if @config.channel
        end

        # When we're exiting, quit our user
        $eventq.handle(:exit) { |reason| quit(@user.key, reason) if @user }
    end

    private

    # Posts snoops
    def snoop(command, str)
        $eventq.post(:snoop, :shrike, command, str)
    end

    public

    # Called by the protocol module to handle commands sent to us
    def irc_privmsg(user, params)
        cmd = params.delete_at(0)
        meth = "do_#{cmd}".downcase.to_sym

        if self.respond_to?(meth, true)
            self.send(meth, user, params)
        else
            notice(@user.key, user.key, "Invalid command: \2#{cmd}\2")
        end
    end
end
