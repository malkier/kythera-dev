# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6.rb: implements the TS6 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Protocol::TS6
end

require 'kythera/protocol/ts6/channel'
require 'kythera/protocol/ts6/receive'
require 'kythera/protocol/ts6/send'
require 'kythera/protocol/ts6/server'
require 'kythera/protocol/ts6/user'

# Implements TS6 protocol-specific methods
module Protocol::TS6
    include Protocol

    # The current UID for Services
    @@current_uid = 'AAAAAA'

    public

    # Introduces a pseudo-client to the network
    #
    # @param [String] nick user's nickname
    # @param [String] user user's username
    # @param [String] host user's hostname
    # @param [String] real user's realname / gecos
    #
    def introduce_user(nick, user, host, real, modes = '')
        send_uid(nick, user, host, real, modes)
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

        send_sjoin(channel.name, channel.timestamp, user.uid)

        channel.add_user(user)

        user.add_status_mode(channel, :operator)

        $eventq.post(:mode_added_on_channel, :operator, user, channel)
    end
end
