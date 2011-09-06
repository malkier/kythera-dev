#
# kythera: services for IRC networks
# lib/kythera/protocol.rb: implements protocol basics
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera/protocol/send'
require 'kythera/protocol/receive'

module Protocol
    # Removes the first character of the string
    REMOVE_FIRST = 1 .. -1

    # Special constant for grabbing mode params
    GET_MODES_PARAMS = 2 ... -1

    # Allows protocol module names to be case-insensitive
    def self.find(mod)
        Protocol.const_get Protocol.constants.find { |c| c =~ /^#{mod}$/i }
    end

    public

    # Sends a string straight to the uplink
    #
    # @param [String] string message to send
    #
    def raw(string)
        @sendq << string
    end

    # Sends a PRIVMSG to a user
    #
    # @param [User] user the user that's sending the message
    # @param target either a User or a Channel or a String
    # @param [String] message the message to send
    #
    def privmsg(user, target, message)
        target = target.origin if target.kind_of?(User)
        target = target.name   if target.kind_of?(Channel)
        send_privmsg(user.origin, target, message)
    end

    # Sends a NOTICE to a user
    #
    # @param [User] user the user that's sending the notice
    # @param target either a User or a Channel or a String
    # @param [String] message the message to send
    #
    def notice(user, target, message)
        target = target.origin if target.kind_of?(User)
        target = target.name   if target.kind_of?(Channel)
        send_notice(user.origin, target, message)
    end

    # Makes one of our clients join a channel
    #
    # @param [User] user the User we want to join
    # @param channel can be a Channel or a String
    #
    def join(user, channel)
        if channel.kind_of?(String)
            if chanobj = $channels[channel]
                channel = chanobj
            else
                # This is a nonexistant channel
                channel = Channel.new(channel)
            end
        end

        send_join(user.origin, channel.name)

        channel.add_user(user)

        user.add_status_mode(channel, :operator)

        $eventq.post(:mode_added_on_channel, :operator, user, channel)
    end

    # Makes one of our clients part a channel
    #
    # @param [User] use the User we want to part
    # @param channel can be a Channel or a String
    # @param [String] reason reason for leaving channel
    #
    def part(user, channel, reason = 'leaving')
        if channel.kind_of?(String)
            return unless channel = $channels[channel]
        end

        return unless @user.is_on?(channel)

        send_part(user.origin, channel.name, reason)

        channel.delete_user(user)
    end

    # Makes one of our clients send a QUIT
    #
    # @param [User] user which client to quit
    # @param [String] reason quit reason if any
    #
    def quit(user, reason = 'signed off')
        send_quit(user.origin, reason)
    end

    # Makes one of our clients set a channel topic
    #
    # @param [User] user topic setter
    # @param channel can be a channel or a string
    # @param [String] topic channel topic
    #
    def topic(user, channel, topic)
        if channel.kind_of?(String)
            return unless channel = $channels[channel]
        end

        send_topic(user.origin, channel.name, topic)
    end

    private

    # Finds a User and Channel or errors
    def find_user_and_channel(origin, name, command)
        unless user = $users[origin]
            $log.error "got non-existant user in #{command}: #{origin}"
        end

        unless channel = $channels[name]
            $log.error "got non-existant channel in #{command}: #{name}"
        end

        [user, channel]
    end
end
