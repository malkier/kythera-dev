# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol.rb: implements protocol basics
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

module Protocol
    # Removes the first character of the string
    REMOVE_FIRST = 1 .. -1

    # Special constant for grabbing mode params in SJOIN
    GET_JOIN_MODE_PARAMS = 2 ... -1

    # Special constant for grabbing mode params in MODE/TMODE/etc
    GET_MODE_PARAMS = 2 .. -1

    # Allows protocol module names to be case-insensitive
    def self.find(mod)
        Protocol.const_get(Protocol.constants.find { |c| c =~ /^#{mod}$/i })
    end

    public

    # Introduces a pseudo-client to the network
    #
    # @param [String] nick user's nickname
    # @param [String] user user's username
    # @param [String] host user's hostname
    # @param [String] real user's realname / gecos
    #
    def introduce_user(nick, user, host, real, modes = [])
        assert { { :nick  => String,
                   :user  => String,
                   :host  => String,
                   :real  => String,
                   :modes => Array } }

        # Translate the mode symbols into an IRC mode string
        imodes = User.modes.invert
        modes  = modes.sort.collect { |m| imodes[m] }.join('')

        # Some protocols use NICK, some use UID, and I like DRY
        if respond_to?(:send_nick, true)
            send_nick(nick, user, host, real, modes)
        elsif respond_to?(:send_uid, true)
            send_uid(nick, user, host, real, modes)
        else
            nil
        end
    end

    # Sends a string straight to the uplink
    #
    # @param [String] string message to send
    #
    def raw(string)
        @sendq << string
    end

    # Sends a WALLOP
    #
    # @param [String] origin the entity sending the message
    # @param [String] message the message to send
    #
    def wallop(origin, message)
        assert { { :origin => String, :message => String } }

        send_wallop(origin, message)
    end

    # Sends a PRIVMSG to a user
    #
    # @param [String] origin the entity sending the message
    # @param [String] target the entity receiving the message
    # @param [String] message the message to send
    #
    def privmsg(origin, target, message)
        assert { { :origin => String, :target => String, :message => String } }

        send_privmsg(origin, target, message)
    end

    # Sends a NOTICE to a user
    #
    # @param [String] origin the entity sending the notice
    # @param [String] target the entity receiving the notice
    # @param [String] message the message to send
    #
    def notice(origin, target, message)
        assert { { :origin => String, :target => String, :message => String } }

        send_notice(origin, target, message)
    end

    # Makes one of our clients part a channel
    #
    # @param [String] origin the entity parting the channel
    # @param [String] target the channel to part
    # @param [String] reason reason for leaving channel
    #
    def part(origin, target, reason = 'leaving')
        assert { { :origin => String, :target => String, :reason => String } }

        user, channel = find_user_and_channel(origin, target, :PART)
        return unless user and channel

        # Part the chanel
        send_part(origin, target, reason)

        # Keep state
        channel.delete_user(user)
    end

    # Makes one of our clients send a QUIT
    #
    # @param [String] origin the entity quitting
    # @param [String] reason quit reason if any
    #
    def quit(origin, reason = 'signed off')
        assert { { :origin => String, :reason => String } }

        send_quit(origin, reason)
    end

    # Makes one of our clients set a channel topic
    #
    # @param [String] origin the entity setting the topic
    # @param [String] target the channel to set the topic on
    # @param [String] topic channel topic
    #
    def topic(origin, target, topic)
        assert { { :origin => String, :target => String, :topic => String } }

        send_topic(origin, target, topic)
    end

    # Sets channel modes, with mode stacking
    #
    # @note Really, the only time to pass a param when deleting modes
    #       is for status modes or :keyed. For :keyed, if passed a param, it's
    #       used; if not passed a param, the key from the passed Channel
    #       object is used. Some protocols require a param, some don't, but all
    #       of them support sending one, so do it.
    #
    # @param [User] origin the User setting the mode
    # @param [Channel] target the Channel to set the mode on
    # @param [Symbol] action :add or :del
    # @param [Array] modes the list of mode symbols
    # @param [Array] params optional list of params for status/param modes
    #
    def channel_mode(origin, target, action, modes, params = [])
        assert { { :target => Channel, :action => Symbol, :modes => Array,
                   :params => Array } }

        assert { { :origin => User } } if origin

        # Do we already have modes for this channel waiting to be sent?
        if mode_stack = ModeStacker.find_by_channel(target.name)
            mode_stack.stack_modes(action, modes, params)
        else
            # No, we don't, so start a new one
            ModeStacker.new(origin, target, action, modes, params)
        end
    end

    # Toggle a status mode for a User on a Channel
    #
    # @param [User] user the User to perform the mode on
    # @param [Channel] channel the Channel to perform the mode on
    # @param [Symbol] mode the mode to toggle
    # @param [String] origin optionally specify a setter for the mode
    #
    def toggle_status_mode(user, channel, mode, origin = nil)
        assert { [:user, :channel] }
        assert { { :mode => Symbol } }

        action = user.has_mode_on_channel?(mode, channel) ? :del : :add

        if action == :add
            user.add_status_mode(channel, mode)
        elsif action == :del
            user.delete_status_mode(channel, mode)
        end

        origin = origin ? origin.key : nil

        channel_mode(origin, channel, action, [mode], [user.key])
    end

    private

    # Finds a User and Channel or errors
    #
    # @param [String] origin the user to find
    # @param [String] target the channel name to find
    # @return [User, Channel]
    #
    def find_user_and_channel(origin, target, command)
        assert { { :origin => String, :target => String, :command => Symbol } }

        unless user = $users[origin]
            $log.error "got non-existent user in #{command}: #{origin}"
        end

        unless channel = $channels[target]
            $log.error "got non-existent channel in #{command}: #{name}"
        end

        [user, channel]
    end
end
