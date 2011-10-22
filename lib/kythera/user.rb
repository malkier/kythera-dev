# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/user.rb: User class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# A list of all users; keyed by nickname by default
$users = IRCHash.new

# This is just a base class; protocol modules should subclass this
class User
    # Standard IRC user modes
    @@modes = { 'i' => :invisible,
                'w' => :wallop,
                'o' => :operator }

    # Some IRCds have umode params
    @@param_modes = {}

    # Attribute reader for `@@modes`
    #
    # @return [Hash] a list of all user modes
    #
    def self.modes
        @@modes
    end

    # A list of Channels we're on
    attr_reader :channels

    # The user's Server object
    attr_reader :server

    # The user's nickname (can change)
    attr_accessor :nickname

    # The user's username
    attr_reader :username

    # The user's hostname
    attr_reader :hostname

    # The user's gecos/realname
    attr_reader :realname

    # The user's timestamp
    attr_accessor :timestamp

    # A Hash keyed by Channel of the user's status modes
    attr_reader :status_modes

    # Creates a new user. Should be patched by the protocol module.
    def initialize(server, nick, user, host, real, umodes, timestamp = nil)
        assert { { :nick   => String,
                   :user   => String,
                   :host   => String,
                   :real   => String,
                   :umodes => String } }

        @server    = server
        @nickname  = nick
        @username  = user
        @hostname  = host
        @realname  = real
        @timestamp = (timestamp || Time.now).to_i
        @modes     = []
        @channels  = []

        @status_modes = {}
        @param_modes  = {}

        # Do our user modes
        unless umodes.empty?
            unless umodes[0].chr == '+' or umodes[0].chr == '-'
                umodes = "+#{umodes}"
            end

            # Pull the params off the mode string
            modes, params = umodes.split(' ', 2)

            # If we have params, tokenize them
            params &&= params.split(' ')

            # Now parse them
            parse_modes(modes, params)
        end

        # Add ourself to the users list and fire the event
        $users[key] = self

        $eventq.post(:user_added, self)

        $log.debug "new user: #{nick}!#{user}@#{host} (#{real})"
    end

    # Delete a user and remove it from all relevant lists
    #
    # @param [User] user User to delete
    # @return [User] the deleted User
    #
    def self.delete_user(user)
        assert { :user }

        user.server.delete_user(user)
        user.channels.dup.each { |channel| channel.delete_user(user) }

        $log.debug "user deleted: #{user}"

        $eventq.post(:user_deleted, user)

        # Also returns the deleted user as a side effect
        $users.delete(user.key)
    end

    public

    # The value we use to represent our membership in a Hash
    def key
        @nickname
    end

    # String representation is just `@nickname`
    def to_s
        @nickname
    end

    # Does this user have the specified umode?
    #
    # @param [Symbol] mode the mode symbol
    # @return [True, False]
    #
    def has_mode?(mode)
        assert { { :mode => Symbol } }

        @modes.include?(mode)
    end

    # Get a mode's param
    #
    # @param [Symbol] mode the mode symbol
    # @return [String] the mode param's value
    #
    def mode_param(mode)
        assert { { :mode => Symbol } }

        @param_modes[mode]
    end

    # Is this user an IRC operator?
    #
    # @return [True, False]
    #
    def operator?
        @modes.include?(:operator)
    end

    # Is this user one a services pseudoclient?
    #
    # @return [True, False]
    #
    def service?
        @server.name == $config.me.name
    end

    # Parses a mode string and updates user state
    #
    # @param [String] modes the mode string
    #
    def parse_modes(modes, params = nil)
        assert { { :modes => String } }

        action = nil # :add or :delete

        modes.each_char do |c|
            mode, param = nil

            if c == '+'
                action = :add
                next
            elsif c == '-'
                action = :delete
                next
            end

            # Do we know about this mode and what it means?
            if mode = @@modes[c]
                if action == :add
                    @modes << mode
                elsif action == :delete
                    @modes.delete(mode)
                end

            elsif mode = @@param_modes[c]
                param = params.shift

                if action == :add
                    @modes << mode
                    @param_modes[mode] = param
                elsif action == :delete
                    @modes.delete(mode)
                    @param_modes.delete(mode)
                end
            end

            if mode
                # Post an event for it
                if action == :add
                    $eventq.post(:mode_added_to_user, mode, param, self)
                elsif action == :delete
                    $eventq.post(:mode_deleted_from_user, mode, param, self)
                end

                $log.debug "mode #{action}: #{self} -> #{mode} #{param}"
            end
        end
    end

    # Adds a status mode for this user on a particular channel
    #
    # @param [Channel] channel the Channel object we have the mode on
    # @param [Symbol] mode a Symbol representing the mode flag
    #
    def add_status_mode(channel, mode)
        assert { { :channel => Channel, :mode => Symbol } }

        (@status_modes[channel] ||= []) << mode

        $log.debug "status mode added: #{@nickname}/#{channel} -> #{mode}"
    end

    # Deletes a status mode for this user on a particular channel
    #
    # @param [Channel] channel the Channel object we have lost the mode on
    # @param [Symbol] mode a Symbol representing the mode flag
    #
    def delete_status_mode(channel, mode)
        assert { { :channel => Channel, :mode => Symbol } }

        unless @status_modes[channel]
            $log.warn "cannot remove mode from a channel with no known modes"
            $log.warn "#{channel} -> #{mode}"

            return
        end

        @status_modes[channel].delete(mode)

        $log.debug "status mode deleted: #{@nickname}/#{channel} -> #{mode}"
    end

    # Deletes all status modes for given channel
    #
    # @param [Channel] channel the Channel object to clear modes for
    #
    def clear_status_modes(channel)
        assert { :channel }

        unless @status_modes[channel]
            $log.warn "cannot clear modes from a channel with no known modes"
            $log.warn "#{channel} -> clear all modes"

            return
        end

        @status_modes[channel] = []
    end

    # Are we on this channel?
    #
    # @param [String, Channel] channel the Channel to check for this User
    # @return [True, False]
    #
    def is_on?(channel)
        channel = $channels[channel] if channel.kind_of?(String)

        !! channel.members[key]
    end

    # Do you have the specified status mode?
    #
    # @param [Symbol] mode the mode symbol
    # @param [String, Channel] channel the Channel
    # @return [True, False]
    #
    def has_mode_on_channel?(mode, channel)
        assert { { :mode => Symbol } }

        channel = $channels[channel] if channel.kind_of?(String)

        return false unless @status_modes[channel]

        @status_modes[channel].include?(mode)
    end
end
