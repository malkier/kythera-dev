# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/twitter.rb: implements the twitter service
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

begin
    require 'oauth'
    require 'twitter'
rescue LoadError
    puts "kythera: twitter service depends on oauth and twitter gems"
    puts "kythera: gem install --remote oauth twitter"
    abort
end

require 'kythera'

require 'kythera/service/twitter/commands'
require 'kythera/service/twitter/configuration'

# Provides services for registering accounts
class TwitterService < Service
    # Our name (for use in the config, etc)
    NAME = :twitter

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
        $log.debug 'twitter: configuration updated!'
    end

    # Instantiate the user service
    def initialize(config)
        @config = config

        @request_tokens = {}
        @access_tokens  = {}
        @twitters       = {}

        $log.info "Twitter service loaded (version #{VERSION})"

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
        $eventq.post(:snoop, :twitter, command, str)
    end

    # Return the OAuth consumer object
    def consumer
        OAuth::Consumer.new(@config.consumer_key,
                            @config.consumer_secret,
                            :site => 'http://api.twitter.com')
    end

    public

    # Called by the protocol module to handle commands sent to us
    def irc_privmsg(user, params)
        cmd = params.delete_at(0)
        meth = "do_#{cmd}".downcase.to_sym

        if self.respond_to?(meth, true)
            self.send(meth, user, params)
        else
            notice(@user.key, user.key, "Invalid command: \2#{cmd.upcase}\2")
        end
    end
end
