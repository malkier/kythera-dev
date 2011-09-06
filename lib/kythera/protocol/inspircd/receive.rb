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
    # parv[0] -> server name
    # parv[1] -> password
    # parv[2] -> hops
    # parv[3] -> sid
    # parv[4] -> description
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
        server = nil

        if parv[1] != @config.receive_password
            $log.error "incorrect password received from `#{@config.name}`"
            self.dead = true
        else
            server = Server.new(parv[3])
        end

        # Make sure their name matches what we expect
        unless parv[0] == @config.name
            $log.error "name mismatch from uplink"
            $log.error "#{parv[0]} != #{@config.name}"

            self.dead = true

            return
        end

        server.name        = parv[0]
        server.description = parv[4]

        $log.debug "new server: #{parv[0]}"

        $eventq.post(:server_added, server)
    end

    def irc_capab(origin, parv)
        if parv[0] == "END"
            send_burst
        end
    end

    # Handles an incoming BURST
    #
    # parv[0] -> timestamp
    #
    def irc_burst(origin, parv)
        ts_delta = parv[0].to_i - Time.now.to_i

        if ts_delta >= 60
            $log.warn "#{@config.name} has excessive TS delta"
            $log.warn "#{parv[3]} - #{Time.now.to_i} = #{ts_delta}"
        elsif ts_delta >= 300
            $log.error "#{@config.name} TS delta exceeds five minutes"
            $log.error "#{parv[3]} - #{Time.now.to_i} = #{ts_delta}"
            self.dead = true
        end
    end

    # Handles an incoming ENDBURST
    def irc_endburst(origin, parv)
        if $state[:bursting]
            delta = Time.now - $state[:bursting]
            $state[:bursting] = false

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

        unless s = Server.servers[origin]
            $log.error "got UID from unknown SID: #{origin}"
            return
        end

        u = User.new(s, p[2], p[5], p[4], p[6], p[-1], p[8], p[0], p[1])

        s.add_user(u)
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
            modes_and_params = parv[GET_MODES_PARAMS]
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
                    $log.error "got non-existant UID in FJOIN: #{uid}"
                    next
                end
            end

            channel.add_user(user)

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
        if origin.length == 3
            user, channel = find_user_and_channel(origin, parv[0], :FMODE)
            return unless user and channel
        else
            if channel = $channels[parv[0]]
                params = parv[GET_MODES_PARAMS]
                modes  = params.delete_at(0)

                channel.parse_modes(modes, params)
            else
                unless user = $users[parv[0]]
                    $log.debug "Got FMODE message for unknown UID: #{parv[0]}"
                    return
                end

                params = parv[GET_MODES_PARAMS]

                user.parse_modes(params[0])
            end
        end
    end

    # Handles an incoming NICK
    #
    # parv[0] -> new nickname
    # parv[1] -> ts
    #
    def irc_nick(origin, parv)
        return unless parv.length == 2 # We don't want TS5 introductions

        unless user = $users[origin]
            $log.error "got nick change for non-existant UID: #{origin}"
            return
        end

        $eventq.post(:nickname_changed, user, parv[0])
        $log.debug "nick change: #{user} -> #{parv[0]} [#{origin}]"

        user.nickname = parv[0]
    end
end
