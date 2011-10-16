# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/inspircd/send.rb: implements the InspIRCd protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# Implements InspIRCd protocol-specific methods
module Protocol::InspIRCd
    private

    # Sends the initial data to the server
    def send_handshake
        $state.bursting = Time.now

        send_capab
        send_server
    end

    # CAPAB START
    # CAPAB CAPABILITIES :VAR=VALUE ...
    # CAPAB MODULES <module list>
    # CAPAB END
    def send_capab
        raw 'CAPAB START'
        # PROTOCOL is the only mandatory argument
        raw 'CAPAB CAPABILITIES :PROTOCOL=1201'
        # we're not a real server so we don't have any modules loaded
        raw 'CAPAB END'
    end

    # SERVER <servername> <password> <hopcount> <id> :<description>
    def send_server
        str  = "SERVER #{$config.me.name} #{@config.send_password} 0 "
        str += "#{@config.sid} :#{$config.me.description}"

        # Keep track of our own server, it counts!
        Server.new(@config.sid, $config.me.name, $config.me.description)

        raw str
    end

    # :<sid> BURST <ts>
    def send_burst
        raw ":#{@config.sid} BURST #{Time.now.to_i}"
    end

    # :<sid> ENDBURST
    def send_endburst
        raw ":#{@config.sid} ENDBURST"
    end

    # :<source> PONG <source> :<destination>
    def send_pong(dest)
        assert { { :dest => String } }

        raw ":#{@config.sid} PONG #{@config.sid} :#{dest}"
    end

    # :<sid> UID <uid> <timestamp> <nick> <hostname> <displayed-hostname>
    #            <ident> <ip> <signon time> +<modes [mode params]> :<gecos>
    def send_uid(nick, user, host, real, modes)
        ts    = Time.now.to_i
        ip    = @config.bind_host || '255.255.255.255'
        id    = @@current_uid
        uid   = "#{@config.sid}#{id}"

        @@current_uid = @@current_uid.next

        str  = ":#{@config.sid} UID #{uid} #{ts} #{nick} #{host} #{host} "
        str += "#{user} #{ip} #{ts} +#{modes} :#{real}"

        raw str

        me = $servers[@config.sid]
        User.new(me, nick, user, host, ip, real, modes, ts, uid)
    end

    # :<sid> FJOIN <channel> <timestamp> +<modes> <params> :<statusmodes,uuid>
    def send_fjoin(target, timestamp, uid)
        assert { { :target => String, :timestamp => Integer, :uid => String } }

        raw ":#{@config.sid} FJOIN #{target} #{timestamp} + o,#{uid}"
    end

    # [:ORIGIN] FMODE <TARGET> <TIMESTAMP> <MODES> [PARAMS]
    def send_fmode(origin, target, timestamp, modestr)
        assert { { :target    => String,
                   :timestamp => Integer,
                   :modestr   => String } }

        if origin
            assert { { :origin => String } }
            raw ":#{origin} FMODE #{target} #{timestamp} #{modestr}"
        else
            raw "FMODE #{target} #{timestamp} #{modestr}"
        end
    end

    # :origin WALLOPS :message
    def send_wallop(origin, message)
        assert { { :origin => String, :message => String } }

        raw ":#{origin} WALLOPS :#{message}"
    end
end
