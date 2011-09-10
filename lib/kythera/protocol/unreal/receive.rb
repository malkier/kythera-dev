#
# kythera: services for IRC networks
# lib/kythera/protocol/unreal/receive.rb: implements UnrealIRCd's protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# Implements Unreal protocol-specific methods
module Protocol::Unreal
    private

    # Handles an incoming PASS
    #
    # parv[0] -> password
    #
    def irc_pass(origin, parv)
        # Start the burst timer
        $state.bursting = Time.now

        if parv[0] != @config.receive_password.to_s
            $log.error "incorrect password received from `#{@config.name}`"
            self.dead = true
        end
    end

    # Handles an incoming PROTOCTL
    #
    # parv[0] -> protocol options
    #
    def irc_protoctl(origin, parv)
        $eventq.post(:start_of_burst, Time.now)
    end

    # Handles an incoming SERVER (server introduction)
    #
    # without origin
    #   parv[0] -> server name
    #   parv[1] -> hops
    #   parv[2] -> server description
    # with origin
    #   parv[0] -> server name
    #   parv[1] -> hops
    #   parv[2] -> description
    #
    def irc_server(origin, parv)
        # No origin means that we're handshaking, so this must be our uplink.
        unless origin
            server = Server.new(parv[0])

            # Make sure their name matches what we expect
            unless parv[0] == @config.name
                $log.error "name mismatch from uplink"
                $log.error "#{parv[0]} != #{@config.name}"

                self.dead = true

                return
            end

            server.description = parv[2]

            $log.debug "new server: #{parv[0]}"

            $eventq.post(:server_added, server)
        else
            server             = Server.new(parv[0])
            server.description = parv[2]
        end
    end

    # Handles an incoming PING
    #
    # parv[0] -> source server
    # parv[1] -> optional destination server (which is us)
    #
    def irc_ping(origin, parv)
        send_pong(parv[0])
    end

    # Handles an incoming NICK
    #
    # if we have an origin, a nick is being changed:
    #   parv[0] -> new nick
    #   parv[1] -> timestamp
    # if we don't have an origin, then a new user is being introduced.
    #   parv[0] -> nick
    #   parv[1] -> hops
    #   parv[2] -> timestamp
    #   parv[3] -> username
    #   parv[4] -> hostname
    #   parv[5] -> server
    #   parv[6] -> servicestamp
    #   parv[7] -> usermodes
    #   parv[8] -> virtualhost
    #   parv[9] -> cloakhost
    #   parv[10] -> realname
    #
    def irc_nick(origin, parv)
        if origin
            unless user = $users[origin]
                $log.error "got nick change for non-existant nick: #{origin}"
                return
            end

            $log.debug "nick change: #{user} -> #{parv[0]}"

            user.nickname = parv[0]
        else
            p = parv

            unless s = $servers[p[5]]
                $log.error "received NICK from unknown server: #{parv[5]}"
                return
            end

            u = User.new(s, p[0], p[3], p[4], p[10], p[7], p[2], p[8], p[9])

            s.add_user(u)
        end
    end

    # Handles an incoming SJOIN (channel burst)
    #
    # parv[0] -> timestamp
    # parv[1] -> channel name
    # parv[2] -> '+' cmodes
    # parv... -> cmode params (if any)
    # parv[-1] -> :members &ban "exempt 'invex
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

            channel.parse_modes(modes, params) unless modes == nil
        end

        # Parse the members list
        members = parv[-1].split(' ')

        # This particular process was benchmarked, and this is the fastest
        # See benchmark/theory/multiprefix_parsing.rb
        #
        members.each do |nick|
            next if %(&"').include?(nick[0].chr)

            owner = admin = op = halfop = voice = false

            if nick[0].chr == '@'
                op   = true
                nick = nick[REMOVE_FIRST]
            end

            if nick[0].chr == '+'
                voice = true
                nick  = nick[REMOVE_FIRST]
            end

            if nick[0].chr == '%'
                halfop = true
                nick   = nick[REMOVE_FIRST]
            end

            if nick[0].chr == '*'
                owner = true
                nick  = nick[REMOVE_FIRST]
            end

            if nick[0].chr == '~'
                admin = true
                nick  = nick[REMOVE_FIRST]
            end

            unless user = $users[nick]
                $log.error "got non-existant nick in SJOIN: #{nick}"
                next
            end

            channel.add_user(user)

            if their_ts <= channel.timestamp
                if owner
                    user.add_status_mode(channel, :owner)

                    $eventq.post(:mode_added_on_channel, :owner, user, channel)
                end

                if admin
                    user.add_status_mode(channel, :admin)

                    $eventq.post(:mode_added_on_channel, :admin, user, channel)
                end

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

    # Handles an incoming MODE
    #
    # parv[0]  -> target
    # parv[1]  -> mode change
    # parv...  -> mode params
    # parv[-1] -> timestamp if origin is a server
    #
    def irc_mode(origin, parv)
        if user = $users[parv[0]]
            user.parse_modes(parv[1])
        else
            channel = $channels[parv[0]]
            return unless channel

            modes  = parv[1]
            params = parv[GET_MODE_PARAMS]

            channel.parse_modes(modes, params)
        end
    end

    # Handles an incoming EOS (end of synch)
    def irc_eos(origin, parv)
        if $state.bursting && origin == @config.name
            send_eos

            delta = Time.now - $state.bursting
            $state.bursting = false

            $eventq.post(:end_of_burst, delta)
        end
    end
end
