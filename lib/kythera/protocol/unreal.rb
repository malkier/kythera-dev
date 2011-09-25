#
# kythera: services for IRC networks
# lib/kythera/protocol/unreal.rb: implements UnrealIRCd's protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Protocol::Unreal
end

require 'kythera/protocol/unreal/channel'
require 'kythera/protocol/unreal/receive'
require 'kythera/protocol/unreal/send'
require 'kythera/protocol/unreal/server'
require 'kythera/protocol/unreal/user'

# Implements Unreal protocol-specific methods
module Protocol::Unreal
    include Protocol

    public

    # Introduces a pseudo-client to the network
    #
    # @param [String] nick user's nickname
    # @param [String] user user's username
    # @param [String] host user's hostname
    # @param [String] real user's realname / gecos
    #
    def introduce_user(nick, user, host, real, modes = '')
        modes += 'S' unless modes.include? 'S'
        send_nick(nick, user, host, real, modes)
    end

    # Makes one of our clients join a channel
    #
    # @param [User] user the User we want to join
    # @param channel can be a Channel or a string
    #
    def join(user, channel)
        if channel.kind_of?(String)
            if chanobj = $channels[channel]
                channel = chanobj
            else
                # This is a nonexistent channel
                channel = Channel.new(channel)
            end
        end

        send_sjoin(channel.name, channel.timestamp, user.nickname)

        channel.add_user(user)

        user.add_status_mode(channel, :operator)

        $eventq.post(:mode_added_on_channel, :operator, user, channel)
    end
end
