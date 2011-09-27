# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/user.rb: User class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# A list of all users; keyed by nickname by default
$users = IRCHash.new

# This is just a base class; protocol modules should subclass this
class User
    # Standard IRC user modes
    @@user_modes = { 'i' => :invisible,
                     'w' => :wallop,
                     'o' => :operator }

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

    # A Hash keyed by Channel of the user's status modes
    attr_reader :status_modes

    # Creates a new user. Should be patched by the protocol module.
    def initialize(server, nick, user, host, real, umodes)
        assert {{ :nick   => String,
                  :user   => String,
                  :host   => String,
                  :real   => String,
                  :umodes => String }}

        @server   = server
        @nickname = nick
        @username = user
        @hostname = host
        @realname = real
        @modes    = []

        @status_modes = {}

        # Do our user modes
        parse_modes(umodes)

        $users[key] = self

        $eventq.post(:user_added, self)

        $log.debug "new user: #{nick}!#{user}@#{host} (#{real})"
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

    # Is this user an IRC operator?
    #
    # @return [True, False]
    #
    def operator?
        @modes.include?(:operator)
    end

    # Parses a mode string and updates user state
    #
    # @param [String] modes the mode string
    #
    def parse_modes(modes)
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
            if @@user_modes.include?(c)
                mode  = @@user_modes[c]

                if action == :add
                    @modes << mode
                else
                    @modes.delete(mode)
                end

                $log.debug "mode #{action}: #{self} -> #{mode}"
            end

            # Post an event for it
            if action == :add
                $eventq.post(:mode_added_to_user, mode, self)
            elsif action == :delete
                $eventq.post(:mode_deleted_from_user, mode, self)
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
