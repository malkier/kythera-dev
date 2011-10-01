# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/p10/receive.rb: implements the P10 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# Implements P10 protocol-specific methods
module Protocol::P10
    private

    # This message sends the link password
    #
    # parv[0] -> password
    #
    def irc_pass(origin, parv)
        if parv[0] != @config.receive_password
            e = "incorrect password received from `#{@config.name}`"
            raise Uplink::DisconnectedError, e
        end

        # Start the burst timer
        $state.bursting = Time.now

        $eventq.post(:start_of_burst, Time.now)
    end

    # This message introduces a server
    #
    # parv[0] -> name
    # parv[1] -> hops
    # parv[2] -> start ts
    # parv[3] -> link ts
    # parv[4] -> protocol
    # parv[5] -> sid / max numeric
    # parv[6] -> '0'
    # parv[7] -> description
    #
    def irc_server(origin, parv)
        if origin
            # If we have an origin, then this is a new server introduction
            return
        else
            # No origin means we're handshaking, so this must be our uplink
            Server.new(parv[5][0 ... 2], parv[0], parv[7])

            # Make sure their name matches what we expect
            unless parv[0] == @config.name
                e = "name mismatch from uplink (#{parv[0]} != #{@config.name})"
                raise Uplink::DisconnectedError, e
            end
        end
    end

    # This message tests the connect
    #
    # parv[0] -> ts
    # parv[1] -> to server
    # parv[2] -> ts again? what? p10 is wacky
    #
    def irc_ping(origin, parv)
        send_pong(parv[0])
    end

    # This message signals the end of burst
    def irc_end_of_burst(origin, parv)
        send_end_of_burst
        send_end_of_burst_ack

        if $state.bursting
            delta = Time.now - $state.bursting
            $state.bursting = false

            $eventq.post(:end_of_burst, delta)
        end
    end
end
