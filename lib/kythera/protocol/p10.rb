# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/p10.rb: implements the P10 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Protocol::P10
end

require 'kythera/protocol/p10/token'
require 'kythera/protocol/p10/channel'
require 'kythera/protocol/p10/receive'
require 'kythera/protocol/p10/send'
require 'kythera/protocol/p10/server'
require 'kythera/protocol/p10/user'

# Implements P10 protocol-specific methods
module Protocol::P10
    include Protocol

    # Special constant for grabbing mode params in MODE
    GET_MODE_PARAMS = 1 .. -2

    # The current UID for Services
    @@current_uid = 0

    public

    # Makes one of our clients join a channel
    #
    # @param [String] origin the entity joining the channel
    # @param [String] target the channel to join
    #
    def join(origin, target)
        assert { { :origin => String, :target => String } }

        unless user = $users[origin]
            $log.warn 'cannot join nonexistent user to channel'
            $log.warn "#{origin} -> #{target}"

            return
        end

        unless channel = $channels[target]
            # This is a nonexistent channel
            channel = Channel.new(target)
        end

        # Do we need to create the channel?
        if channel.members.empty?
            ret = send_create(user.uid, channel.name, channel.timestamp)

            # CREATE automatically ops them, keep state
            user.add_status_mode(channel, :operator)
            $eventq.post(:mode_added_on_channel, :operator, user, channel)
        else
            ret = send_join(user.uid, channel.name, channel.timestamp)
            toggle_status_mode(user, channel, :operator)
        end

        # Keep state
        channel.add_user(user)

        ret
    end

    # Toggle a status mode for a User on a Channel
    #
    # @param [User] user the User to be opped/deopped
    # @param [Channel] channel the Channel to op/deop on
    # @param [Symbol] mode the mode to toggle
    # @param [String] origin optionally specify a setter for the mode
    #
    def toggle_status_mode(user, channel, mode, origin = nil)
        assert { [:user, :channel] }
        assert { { :mode => Symbol } }
        assert { { :origin => String } } if origin

        del = user.has_mode_on_channel?(mode, channel)
        chr = Channel.status_modes.find { |k, v| v == mode }[0]
        str = "#{del ? '-' : '+'}#{chr} #{user.uid}"

        if del
            user.delete_status_mode(channel, mode)
            $eventq.post(:mode_added_on_channel, mode, user, channel)
        else
            user.add_status_mode(channel, mode)
            $eventq.post(:mode_deleted_on_channel, mode, user, channel)
        end

        name, ts = channel.name, channel.timestamp

        send_opmode(origin ? origin : @config.sid, name, str, ts)
    end
end
