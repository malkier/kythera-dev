# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/inspircd/receive.rb: implements the InspIRCd protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# Implements InspIRCd protocol-specific methods
module Protocol::InspIRCd
    private

    # Handles an incoming SERVER
    #
    # Authentication:
    #     parv[0] -> server name
    #     parv[1] -> password
    #     parv[2] -> hops
    #     parv[3] -> sid
    #     parv[4] -> description
    #
    # New server introduction:
    #     origin  -> local SID
    #     parv[0] -> server name
    #     parv[1] -> *
    #     parv[2] -> hops
    #     parv[3] -> SID
    #     parv[4] -> description
    #
    def irc_server(origin, parv)
        Server.new(parv[3], parv[0], parv[4])

        return if origin # Anything else is authentication

        unless parv[1] == @config.receive_password
            e = "incorrect password received from `#{@config.name}`"
            raise Uplink::DisconnectedError, e
        end

        # Make sure their name matches what we expect
        unless parv[0] == @config.name
            e = "name mismatch from uplink (#{parv[0]} != #{@config.name})"
            raise Uplink::DisconnectedError, e
        end
    end

    # Handles an incoming CAPAB
    #
    # We only care about it if parv[0] is 'END'
    #
    def irc_capab(origin, parv)
        if parv[0] == "END"
            send_burst
            $eventq.post(:start_of_burst, Time.now)
        end
    end

    # Handles an incoming BURST
    #
    # parv[0] -> timestamp
    #
    def irc_burst(origin, parv)
        ts_delta = parv[0].to_i - Time.now.to_i

        if ts_delta >= 60
            e  = "#{@config.name} has excessive TS delta "
            e += "(#{parv[0]} - #{Time.now.to_i} = #{ts_delta})"
            raise Uplink::DisconnectedError, e
        elsif ts_delta >= 300
            e  = "#{@config.name} TS delta exceeds five minutes"
            e += "(#{parv[0]} - #{Time.now.to_i} = #{ts_delta})"
            raise Uplink::DisconnectedError, e
        end
    end

    # Handles an incoming ENDBURST
    def irc_endburst(origin, parv)
        send_endburst

        if $state.bursting
            delta = Time.now - $state.bursting
            $state.bursting = false

            $eventq.post(:end_of_burst, delta)
        end
    end

    # Handles an incoming UID
    #
    # parv[0]  -> uid
    # parv[1]  -> timestamp
    # parv[2]  -> nick
    # parv[3]  -> hostname
    # parv[4]  -> displayed hostname
    # parv[5]  -> ident
    # parv[6]  -> ip
    # parv[7]  -> signon time
    # parv[8]  -> '+' umodes
    # parv...  -> mode params
    # parv[-1] -> real name
    #
    def irc_uid(origin, parv)
        p = parv

        unless server = $servers[origin]
            $log.error "got UID from unknown SID: #{origin}"
            return
        end

        u = User.new(server, p[2], p[5], p[4], p[6], p[-1], p[8], p[1], p[0])

        server.add_user(u)
    end

    # Handles an incoming FJOIN
    #
    # parv[0]  -> channel
    # parv[1]  -> timestamp
    # parv[2]  -> modes
    # parv...  -> mode params
    # parv[-1] -> statusmodes,uid as list
    #
    def irc_fjoin(origin, parv)
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

        # Parse channel modes
        if their_ts <= channel.timestamp
            modes_and_params = parv[GET_JOIN_MODE_PARAMS]
            modes  = modes_and_params[0]
            params = modes_and_params[REMOVE_FIRST]

            channel.parse_modes(modes, params) unless modes == '0'
        end

        # Parse the members list
        members = parv[-1].split(' ')

        members.each do |uid|
            modes, uid = uid.split(',')

            modes = modes.split('')

            unless user = $users[uid]
                # Maybe it's a nickname?
                user = $users.values.find { |u| u.nickname == uid }
                unless user
                    $log.error "got non-existent UID in FJOIN: #{uid}"
                    next
                end
            end

            channel.add_user(user)

            # Only do status modes if the TS is right
            if their_ts <= channel.timestamp
                modes.each do |m|
                    mode = Channel.status_modes[m]

                    user.add_status_mode(channel, mode)

                    $eventq.post(:mode_added_on_channel, mode, user, channel)
                end
            end
        end
    end

    # Handles an incoming PING
    #
    # parv[0] -> source
    # parv[1] -> destination
    #
    def irc_ping(origin, parv)
        send_pong(parv[0])
    end

    # Handles an incoming FMODE
    #
    # parv[0] -> target
    # parv[1] -> timestamp
    # parv[2] -> modes
    # parv... -> mode parameters
    #
    def irc_fmode(origin, parv)
        if channel = $channels[parv[0]]
            their_ts = parv[1].to_i
            my_ts    = channel.timestamp

            # Simple TS rules
            if their_ts <= my_ts
                params = parv[GET_MODE_PARAMS]
                modes  = params.delete_at(0)

                channel.parse_modes(modes, params)
            else
                $log.warn "invalid ts for #{channel} (#{their_ts} > #{my_ts})"
            end
        else
            unless user = $users[parv[0]]
                $log.debug "Got FMODE message for unknown UID: #{parv[0]}"
                return
            end

            params = parv[GET_MODE_PARAMS]

            user.parse_modes(params[0])
        end
    end

    # Handles an incoming NICK
    #
    # parv[0] -> new nickname
    # parv[1] -> ts
    #
    def irc_nick(origin, parv)
        unless user = $users[origin]
            $log.error "got nick change for non-existent UID: #{origin}"
            return
        end

        $eventq.post(:nickname_changed, user, parv[0])
        $log.debug "nick change: #{user} -> #{parv[0]} [#{origin}]"

        user.nickname  = parv[0]
        user.timestamp = parv[1].to_i
    end
end
