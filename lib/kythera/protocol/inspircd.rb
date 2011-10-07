# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/inspircd.rb: implements the InspIRCd protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

module Protocol::InspIRCd
end

require 'kythera/protocol/inspircd/channel'
require 'kythera/protocol/inspircd/receive'
require 'kythera/protocol/inspircd/send'
require 'kythera/protocol/inspircd/server'
require 'kythera/protocol/inspircd/user'

# Implements InspIRCd protocol-specific methods
module Protocol::InspIRCd
    include Protocol

    # The current UID for Services
    @@current_uid = 'AAAAAA'

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

        # Join the channel
        send_fjoin(channel.name, channel.timestamp, user.uid)

        # Keep state
        channel.add_user(user)

        # FJOIN will automatically op them, keep state
        user.add_status_mode(channel, :operator)
        $eventq.post(:mode_added_on_channel, :operator, user, channel)
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

        del = user.has_mode_on_channel?(mode, channel)
        chr = Channel.status_modes.values.find { |m| m == mode }
        str = "#{del ? '-' : '+'}#{chr} #{user.uid}"

        if del
            user.delete_status_mode(channel, mode)
            $eventq.post(:mode_deleted_on_channel, mode, user, channel)
        else
            user.add_status_mode(channel, mode)
            $eventq.post(:mode_added_on_channel, mode, user, channel)
        end

        send_fmode(origin ? origin.uid : nil, channel, channel.timestamp, str)
    end
end
