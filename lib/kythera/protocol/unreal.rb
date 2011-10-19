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
        ret = send_sjoin(channel.name, channel.timestamp, user.nickname)

        # SJOIN automatically ops them, keep state
        user.add_status_mode(channel, :operator)
        $eventq.post(:mode_added_on_channel, :operator, user, channel)

        # Keep state
        channel.add_user(user)

        ret
    end

    # Abstracted way to send a mode change to a channel
    #
    # @param [nil, String] origin optional origin of mode
    # @param [String] target channel to send mode to
    # @param [Integer] timestamp the channel's timestamp
    # @param [String] modestr the mode string
    #
    def send_channel_mode(origin, target, timestamp, modestr)
        assert { { :target    => String, :modestr => String,
                   :timestamp => Integer } }

        assert { { :origin    => String  } } if origin

        send_mode(origin, target, modestr, timestamp)
    end
end
