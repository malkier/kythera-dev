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

    # Sends an WALLOP
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
