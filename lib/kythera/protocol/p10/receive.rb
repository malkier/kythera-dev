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

    # This message introduces a user to the network
    #
    # parv[0] -> nick
    # parv[1] -> hops
    # parv[2] -> ts
    # parv[3] -> user
    # parv[4] -> host
    # parv[5] -> +modes (optional, apparently)
    # parv[6] -> ip
    # parv[7] -> uid
    # parv[8] -> real
    #
    def irc_nick(origin, parv)
        p = parv

        unless server = $servers[origin]
            $log.error "got UID from unknown SID: #{origin}"
            return
        end

        if parv[5][0].chr == '+'
            # P10 breaks my dick once again by sending umodes with params
            # XXX - attach their Account to this...
            account = parv.delete_at(6) if parv[5].include?('r')

            u = User.new(server, p[0], p[3], p[4], p[6], p[8], p[5], p[7], p[2])
        else
            u = User.new(server, p[0], p[3], p[4], p[5], p[7], '+', p[6], p[2])
        end

        server.add_user(u)
    end

    # This message bursts channel information
    #
    # parv[0]  -> name
    # parv[1]  -> ts
    #
    # If there are modes, parv[2] will be the modes, and parv[3] and parv[4]
    # *might* be mode params. They could also be the member or ban list.
    #
    # If there aren't modes, parv[2] could be the members or ban list.
    # If there aren't users, parv[2] could be the ban list or nothing.
    #
    def irc_burst(origin, parv)
        their_ts = parv[1].to_i

        # Do we already have this channel?
        if channel = $channels[parv[0]]
            if their_ts < channel.timestamp
                # Remove our status modes, channel modes, and bans
                channel.members.each_value { |u| u.clear_status_modes(channel) }
                channel.clear_modes
                channel.timestamp = their_ts
            end
        else
            channel = Channel.new(parv[0], parv[1])
        end

        # Initialize these so they're in our scope
        modes   = '+'
        params  = []
        members = ''
        bans    = ''

        # Since pretty much any param can be pretty much anything, we have
        # to actually loop through each one to test it for various things
        # to figure out what it is. P10 is fucking retarded.
        #
        parv.each do |param|
            # If the first character is a '+', this is the mode list
            if param[0].chr == '+'
                modes_and_params = parv[GET_JOIN_MODE_PARAMS]
                modes  = modes_and_params[0]
                params = modes_and_params[REMOVE_FIRST]

            # If the first character is a '%', this is the ban list.
            elsif param[0].chr == '%'
                bans = param

            # If the param has commas in it, it's the member list.
            elsif param.include?(',')
                members = param
            end
        end

        # Parse channel modes
        if their_ts <= channel.timestamp
            channel.parse_modes(modes, params) unless modes == '0'

            # Parse channel bans
            bans = bans[REMOVE_FIRST].split(' ')

            bans.each do |hostmask|
                channel.parse_modes('+b', [hostmask])
            end
        end

        # Parse the member list
        members = members.split(',')

        op = voice = false

        members.each do |uid|
            uid, modes = uid.split(':')

            if modes
                op    = modes.include?('o') ? true : false
                voice = modes.include?('v') ? true : false
            end

            unless user = $users[uid]
                $log.error "got non-existent UID in SJOIN: #{uid}"
                next
            end

            channel.add_user(user)

            # Only apply status modes if the TS is right
            if their_ts <= channel.timestamp
                if op
                    user.add_status_mode(channel, :operator)

                    $eventq.post(:mode_added_on_channel,
                                :operator, user, channel)
                end

                if voice
                    user.add_status_mode(channel, :voice)

                    $eventq.post(:mode_added_on_channel, :voice, user, channel)
                end
            end
        end
    end
end
