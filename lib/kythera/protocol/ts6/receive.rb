# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6/receive.rb: implements the TS6 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# Implements TS6 protocol-specific methods
module Protocol::TS6
    private

    # Handles an incoming PASS
    #
    # parv[0] -> password
    # parv[1] -> 'TS'
    # parv[2] -> ts version
    # parv[3] -> sid of remote server
    #
    def irc_pass(origin, parv)
        if parv[0] != @config.receive_password
            e = "incorrect password received from `#{@config.name}`"
            raise Uplink::DisconnectedError, e
        else
            # Because the SID and the name isn't ever seen in one place, we
            # have to hack this together, and it blows to the max
            $state.uplink_sid = parv[3]

            # Start the burst timer
            $state.bursting = Time.now

            $eventq.post(:start_of_burst, Time.now)
        end
    end

    # Handles an incoming SERVER
    #
    # parv[0] -> server name
    # parv[1] -> hops
    # parv[2] -> server description
    #
    def irc_server(origin, parv)
        if origin
            # If we have an origin, then this is a new server introduction.
            # However this is a TS5 introduction, and we only support TS6-only
            # networks, so spit out a warning and ignore it.
            #
            $log.warn 'got non-TS6 server introduction on TS6-only network:'
            $log.warn "#{parv[0]} (#{parv[2]})"

            return
        end

        # No origin means we're handshaking, so this must be our uplink
        Server.new($state.uplink_sid, parv[0], parv[2])

        # Make sure their name matches what we expect
        unless parv[0] == @config.name
            e = "name mismatch from uplink (#{parv[0]} != #{@config.name})"
            raise Uplink::DisconnectedError, e
        end
    end

    # Handles an incoming SVINFO
    #
    # parv[0] -> max ts version
    # parv[1] -> min ts version
    # parv[2] -> '0'
    # parv[3] -> current ts
    #
    def irc_svinfo(origin, parv)
        ts_delta = parv[3].to_i - Time.now.to_i

        if parv[0].to_i < 6
            e = "#{config.name} doesn't support TS6"
            raise Uplink::DisconnectedError, e
        elsif ts_delta >= 60
            e  = "#{@config.name} has excessive TS delta "
            e += "(#{parv[3]} - #{Time.now.to_i} = #{ts_delta})"
            raise Uplink::DisconnectedError, e
        elsif ts_delta >= 300
            e  = "#{@config.name} TS delta exceeds five minutes"
            e += "(#{parv[3]} - #{Time.now.to_i} = #{ts_delta})"
            raise Uplink::DisconnectedError, e
        end
    end

    # Handles an incoming PING
    #
    # parv[0] -> sid of remote server
    #
    def irc_ping(origin, parv)
        send_pong(parv[0])

        if $state.bursting
            delta = Time.now - $state.bursting
            $state.bursting = false

            $eventq.post(:end_of_burst, delta)
        end
    end

    # Handles an incoming SID (server introduction)
    #
    # parv[0] -> server name
    # parv[1] -> hops
    # parv[2] -> sid
    # parv[3] -> description
    #
    def irc_sid(origin, parv)
        server = Server.new(parv[2], parv[0], parv[3])
    end

    # Handles an incoming UID (user introduction)
    #
    # parv[0] -> nickname
    # parv[1] -> hops
    # parv[2] -> timestamp
    # parv[3] -> '+' umodes
    # parv[4] -> username
    # parv[5] -> hostname
    # parv[6] -> ip
    # parv[7] -> uid
    # parv[8] -> realname
    #
    def irc_uid(origin, parv)
        p = parv

        unless server = $servers[origin]
            $log.error "got UID from unknown SID: #{origin}"
            return
        end

        u = User.new(server, p[0], p[4], p[5], p[6], p[8], p[3], p[7], p[2])

        server.add_user(u)
    end

    # Handles an incoming NICK
    #
    # parv[0] -> new nickname
    # parv[1] -> ts
    #
    def irc_nick(origin, parv)
        return unless parv.length == 2 # We don't want TS5 introductions

        unless user = $users[origin]
            $log.error "got nick change for non-existent UID: #{origin}"
            return
        end

        $eventq.post(:nickname_changed, user, parv[0])
        $log.debug "nick change: #{user} -> #{parv[0]} [#{origin}]"

        user.nickname  = parv[0]
        user.timestamp = parv[1].to_i
    end

    # Handles an incoming SJOIN (channel burst)
    #
    # parv[0] -> timestamp
    # parv[1] -> channel name
    # parv[2] -> '+' cmodes
    # parv... -> cmode params (if any)
    # parv[-1] -> members as UIDs
    #
    def irc_sjoin(origin, parv)
        their_ts = parv[0].to_i

        # Do we already have this channel?
        if channel = $channels[parv[1]]
            if their_ts < channel.timestamp
                # Remove our status modes, channel modes, and bans
                channel.members.each_value { |u| u.clear_status_modes(channel) }
                channel.clear_modes
                channel.timestamp = their_ts
            end
        else
            channel = Channel.new(parv[1], parv[0])
        end

        # Parse channel modes
        if their_ts <= channel.timestamp
            modes_and_params = parv[GET_JOIN_MODE_PARAMS]
            modes  = modes_and_params[0]
            params = modes_and_params[REMOVE_FIRST]

            channel.parse_modes(modes, params) unless modes == '0'
        end

        # Parse the members list
        members = parv[-1].split(' ')

        # This particular process was benchmarked, and this is the fastest
        # See benchmark/theory/multiprefix_parsing.rb
        #
        members.each do |uid|
            op = voice = false

            if uid[0].chr == '@'
                op  = true
                uid = uid[REMOVE_FIRST]
            end

            if uid[0].chr == '+'
                voice = true
                uid   = uid[REMOVE_FIRST]
            end

            unless user = $users[uid]
                # Maybe it's a nickname?
                user = $users.values.find { |u| u.nickname == uid }

                unless user
                    $log.error "got non-existent UID in SJOIN: #{uid}"
                    next
                end
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

    # Handles an incoming JOIN (non-burst channel join)
    #
    # parv[0] -> timestamp
    # parv[1] -> channel name
    # parv[2] -> '+'
    #
    def irc_join(origin, parv)
        user, channel = find_user_and_channel(origin, parv[1], :JOIN)
        return unless user and channel

       if parv[0].to_i < channel.timestamp
           # Remove our status modes, channel modes, and bans
           channel.members.each { |u| u.clear_status_modes(channel) }
           channel.clear_modes
           channel.timestamp = parv[0].to_i
       end

       # Add them to the channel
       channel.add_user(user)
    end

    # Handles an incoming TMODE
    #
    # parv[0] -> timestamp
    # parv[1] -> channel name
    # parv[2] -> mode string
    #
    def irc_tmode(origin, parv)
        return unless channel = $channels[parv[1]]

        their_ts = parv[0].to_i
        my_ts    = channel.timestamp

        # Simple TS rules
        if their_ts <= my_ts
            params = parv[GET_MODE_PARAMS]
            modes  = params.delete_at(0)

            channel.parse_modes(modes, params)
        else
            $log.warn "invalid ts for #{channel} (#{their_ts} > #{my_ts})"
        end
    end

    # Handles an incoming MODE
    #
    # parv[0] -> UID of the user with the mode change
    # parv[1] -> mode string
    #
    def irc_mode(origin, parv)
        unless user = $users[parv[0]]
            $log.debug "Got MODE message for unknown UID: #{parv[0]}"
            return
        end

        user.parse_modes(parv[1])
    end

    # Handles an incoming BMASK
    #
    # parv[0] -> timestamp
    # parv[1] -> channel
    # parv[2] -> mode char
    # parv[3] -> space-delimited list of hostmasks
    #
    def irc_bmask(origin, parv)
        return unless channel = $channels[parv[1]]

        their_ts = parv[0].to_i
        my_ts    = channel.timestamp

        # Simple TS rules
        if their_ts <= my_ts
            params = parv[3].split(' ')
            modes  = '+' + parv[2] * params.length

            channel.parse_modes(modes, params)
        else
            $log.warn "invalid ts for #{channel} (#{their_ts} > #{my_ts})"
        end
    end
end
