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
        ret = send_fjoin(channel.name, channel.timestamp, user.uid)

        # Keep state
        channel.add_user(user)

        # FJOIN will automatically op them, keep state
        user.add_status_mode(channel, :operator)
        $eventq.post(:mode_added_on_channel, :operator, user, channel)

        ret
    end

    # Send a set of modes contained in a ChannelMode to the uplink
    #
    # @params [Protocol::ChannelMode] cmode the ChannelMode to process
    #
    def format_and_send_channel_mode(cmode)
        #assert { { :cmode => ::Protocol::ChannelMode } }

        modes, params = format_channel_mode(cmode)

        modestr   = "#{modes} #{params}"
        origin    = cmode.user ? cmode.user.key : nil
        target    = cmode.channel.name
        timestamp = cmode.channel.timestamp

        send_fmode(origin, target, timestamp, modestr)

        Protocol::ChannelMode.delete(cmode)
    end
end
