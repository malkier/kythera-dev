# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/unreal.rb: implements UnrealIRCd's protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

module Protocol::Unreal
end

require 'kythera/protocol/unreal/channel'
require 'kythera/protocol/unreal/receive'
require 'kythera/protocol/unreal/send'
require 'kythera/protocol/unreal/user'

# Implements Unreal protocol-specific methods
module Protocol::Unreal
    include Protocol

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
        send_sjoin(channel.name, channel.timestamp, user.nickname)

        # SJOIN automatically ops them, keep state
        user.add_status_mode(channel, :operator)
        $eventq.post(:mode_added_on_channel, :operator, user, channel)

        # Keep state
        channel.add_user(user)
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

        send_mode(origin, target, modestr)

        Protocol::ChannelMode.delete(cmode)
    end
end
