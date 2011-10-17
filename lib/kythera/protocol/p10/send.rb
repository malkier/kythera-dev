# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/p10/send.rb: implements the P10 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# Implements P10 protocol-specific methods
module Protocol::P10
    private

    # Sends the initial data to the server
    def send_handshake
        send_pass
        send_server
    end

    # PASS :<PASS>
    def send_pass
        raw "PASS :#{@config.send_password}"
    end

    # <SID> <NAME> <HOPS> <START TIME> <LINK TIME> <PROTOCOL> <NUMERIC> :<DESC>
    def send_server
        n    = $config.me.name
        st   = $state.start_time.to_i
        lt   = Time.now.to_i
        desc = $config.me.description
        sid  = @config.sid

        # Keep track of our own server, it counts!
        Server.new(@config.sid, $config.me.name, $config.me.description)

        raw "SERVER #{n} 1 #{st} #{lt} J10 #{sid}]]] :#{desc}"
    end

    # <SID> EB
    def send_end_of_burst
        raw "#{@config.sid} #{Tokens[:end_of_burst]}"
    end

    # <SID> EA
    def send_end_of_burst_ack
        raw "#{@config.sid} #{Tokens[:end_of_burst_ack]}"
    end

    # <SID> Z <SID> :ts
    def send_pong(ts)
        raw "#{@config.sid} #{Tokens[:pong]} #{@config.sid} :#{ts}"
    end

    # <SID> N <nick> <hops> <ts> <user> <host> +<modes> <ip> <uid> :<real>
    def send_nick(nick, user, host, real, modes)
        ts    = Time.now.to_i
        ip    = @config.bind_host || '255.255.255.255'
        ip    = Protocol::P10.base64_encode(IPAddr.new(ip).to_i, 0)
        id    = Protocol::P10.integer_to_uid(@@current_uid)
        uid   = "#{@config.sid}#{id}"
        cmd   = Tokens[:nick]

        @@current_uid = @@current_uid.next

        str  = "#{@config.sid} #{cmd} #{nick} 1 #{ts} #{user} #{host} +#{modes}"
        str += " #{ip} #{uid} :#{real}"

        raw str

        me = $servers[@config.sid]
        User.new(me, nick, user, host, ip, real, modes, ts, uid)
    end

    # <UID> C <target>
    def send_create(uid, target, timestamp)
        assert { { :uid => String, :target => String, :timestamp => Integer } }

        raw "#{uid} #{Tokens[:create]} #{target} #{timestamp}"
    end

    # <UID> J <target>
    def send_join(uid, target, timestamp)
        assert { { :uid => String, :target => String, :timestamp => Integer } }

        raw "#{uid} #{Tokens[:join]} #{target} #{timestamp}"
    end

    # <UID> WA :message
    def send_wallop(uid, message)
        assert { { :uid => String, :message => String } }

        raw "#{uid} #{Tokens[:wallops]} :#{message}"
    end

    # <UID> P <target> :<message>
    def send_privmsg(uid, target, message)
        assert { { :uid => String, :target => String, :message => String } }

        raw "#{uid} #{Tokens[:privmsg]} #{target} :#{message}"
    end

    # <UID> O <target> :<message>
    def send_notice(uid, target, message)
        assert { { :uid => String, :target => String, :message => String } }

        raw "#{uid} #{Tokens[:notice]} #{target} :#{message}"
    end

    # <UID> OM <target> <modestr> <ts>
    def send_opmode(target, modestr, timestamp)
        assert { { :target    => String,
                   :modestr   => String,
                   :timestamp => Integer } }

        origin = @config.sid

        raw "#{origin} #{Tokens[:opmode]} #{target} #{modestr} #{timestamp}"
    end
end
