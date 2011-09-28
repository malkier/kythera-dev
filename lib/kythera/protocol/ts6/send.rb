# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6/send.rb: implements the TS6 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# Implements TS6 protocol-specific methods
module Protocol::TS6
    private

    # Sends the initial data to the server
    def send_handshake
        send_pass
        send_capab
        send_server
        send_svinfo
    end

    # PASS <PASSWORD> TS <TS_CURRENT> :<SID>
    def send_pass
        raw "PASS #{@config.send_password} TS 6 :#{@config.sid}"
    end

    # CAPAB :<CAPABS>
    def send_capab
        raw 'CAPAB :QS EX IE KLN UNKLN ENCAP'
    end

    # SERVER <NAME> <HOPS> :<DESC>
    def send_server
        # Keep track of our own server, it counts!
        Server.new(@config.sid, $config.me.name, $config.me.description)

        raw "SERVER #{$config.me.name} 1 :#{$config.me.description}"
    end

    # SVINFO <MAX_TS_VERSION> <MIN_TS_VERSION> 0 :<TS>
    def send_svinfo
        raw "SVINFO 6 6 0 :#{Time.now.to_i}"
    end

    # PONG <NAME> :<PARAM>
    def send_pong(param)
        assert { { :param => String } }

        raw "PONG #{$config.me.name} :#{param}"
    end

    # UID <NICK> 1 <TS> +<UMODES> <USER> <HOST> <IP> <UID> :<REAL>
    def send_uid(nick, uname, host, real, modes = '')
        ts    = Time.now.to_i
        ip    = @config.bind_host || '255.255.255.255'
        id    = @@current_uid
        uid   = "#{@config.sid}#{id}"
        modes = "+#{modes}"

        @@current_uid = @@current_uid.next

        str  = "UID #{nick} 1 #{ts} #{modes} #{uname} #{host} #{ip} #{uid} :"
        str += real

        raw str

        me = $servers[@config.sid]
        User.new(me, nick, uname, host, ip, real, modes, uid, ts)
    end

    # :UID PRIVMSG <TARGET_UID> :<MESSAGE>
    def send_privmsg(origin, target, message)
        assert { { :origin => String, :target => String, :message => String } }

        raw ":#{origin} PRIVMSG #{target} :#{message}"
    end

    # :UID NOTICE <TARGET_UID> :<MESSAGE>
    def send_notice(origin, target, message)
        assert { { :origin => String, :target => String, :message => String } }

        raw ":#{origin} NOTICE #{target} :#{message}"
    end

    # SJOIN <TS> <CHANNAME> +<CHANMODES> :<UIDS>
    def send_sjoin(target, timestamp, uid)
        assert { { :origin => String, :timestamp => Fixnum, :uid => String } }

        raw "SJOIN #{timestamp} #{target} + :@#{uid}"
    end

    # :<UID> JOIN <TS> <CHANNAME> +
    def send_join(uid, target, timestamp)
        assert { { :uid => String, :target => String, :timestamp => Fixnum } }

        raw ":#{uid} JOIN #{timestamp} #{target} +"
    end

    # [:ORIGIN] TMODE <TS> <CHANNAME> <MODES> [PARAMS]
    def send_tmode(origin, target, timestamp, modestr)
        assert { { :target    => String,
                   :timestamp => Fixnum,
                   :modestr   => String } }

        if origin
            assert { { :origin => String } }
            raw ":#{origin} TMODE #{timestamp} #{target} #{modestr}"
        else
            raw "TMODE #{timestamp} #{target} #{modestr}"
        end
    end
end
