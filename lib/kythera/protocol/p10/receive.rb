# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/p10/receive.rb: implements the P10 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
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
        Server.new(parv[5][0 ... 2], parv[0], parv[7])

        # No origin means we're handshaking, so this must be our uplink
        unless origin
            # Make sure their name matches what we expect
            unless parv[0] == @config.name
                e = "name mismatch from uplink (#{parv[0]} != #{@config.name})"
                raise Uplink::DisconnectedError, e
            end
        end
    end

    # This messages signals the departure of a server
    #
    # parv[0] -> server name
    # parv[1] -> ts
    # parv[2] -> reason
    #
    def irc_squit(origin, parv)
        unless server = $servers.values.find { |s| s.name == parv[0] }
            $log.error "received SQUIT for unknown server: #{parv[0]}"
            return
        end

        return unless server = $servers.delete(server.sid)

        # Remove all their users to comply with CAPAB QS
        server.users.dup.each { |user| User.delete_user(user) }

        $log.debug "server leaving: #{parv[0]} (#{parv[2]})"
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
        if $state.bursting
            send_end_of_burst

            delta = Time.now - $state.bursting
            $state.bursting = false

            $eventq.post(:end_of_burst, delta)
        end

        send_end_of_burst_ack
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

        # This is a nickname change
        if parv.length == 2
           unless user = $users[origin]
               $log.error "got nick change for non-existent UID: #{origin}"
               return
           end

           $eventq.post(:nickname_changed, user, parv[0])
           $log.debug "nick change: #{user} -> #{parv[0]} [#{origin}]"

           user.nickname  = parv[0]
           user.timestamp = parv[1].to_i

           return
        end

        # Otherwise, it's a user introduction
        unless server = $servers[origin]
            $log.error "got UID from unknown SID: #{origin}"
            return
        end

        if parv[5][0].chr == '+'
            # P10 breaks my dick once again by sending umodes with params
            # XXX - attach their Account to this...
            if parv[5].include?('r')
                account = parv.delete_at(6)
                p[5] = "#{p[5]} #{account}"
            end

            u = User.new(server, p[0], p[3], p[4], p[6], p[8], p[5], p[2], p[7])
        else
            u = User.new(server, p[0], p[3], p[4], p[5], p[7], '+', p[2], p[6])
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
        # Zannels are more of p10's absolute retardedness
        return if parv.length == 2

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
        bans    = []

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

        # If there's no modes and no bans, it has to be for members...
        members = parv[2] if modes == '+' and bans.empty?

        # Parse channel modes
        if their_ts <= channel.timestamp
            channel.parse_modes(modes, params)

            # Parse channel bans
            bans = bans[REMOVE_FIRST].split(' ') unless bans.empty?

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
                m = modes

                # We'll just count the dumb OPLEVELS stuff as +o
                if m.include?('o') or m.include?('0') or m.include?('1')
                    op = true
                else
                    op = false
                end

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

    # Creates a new channel
    #
    # parv[0] -> channel
    # parv[1] -> ts
    #
    def irc_create(origin, parv)
        return unless user = $users[origin]

        channel = Channel.new(parv[0], parv[1])

        channel.add_user(user)
    end

    # Changes a mode on a user or channel
    #
    # parv[0]  -> target
    # parv[1]  -> modes
    # parv[-1] -> ts (if target is a channel)
    #
    def irc_mode(origin, parv)
        # This is a umode
        if parv.length == 2
            return unless user = $users[origin]
            user.parse_modes(parv[1])
            return
        end

        # Otherwise it's a channel
        return unless channel = $channels[parv[0]]

        their_ts = parv[-1].to_i
        my_ts    = channel.timestamp

        # Simple TS rules
        if their_ts <= my_ts
            params = parv[GET_MODE_PARAMS]
            modes  = params.delete_at(0)

            # If OPLEVELS is enabled we can have colons in the UID, and
            # we really don't care about OPLEVELS so let's just ignore it
            #
            params.collect! { |param| param.split(':')[0] }

            channel.parse_modes(modes, params)
        else
            $log.warn "invalid ts for #{channel} (#{their_ts} > #{my_ts})"
        end
    end
end
