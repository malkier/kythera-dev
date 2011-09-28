# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/unreal/send.rb: implements UnrealIRCd's protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# Implements Unreal protocol-specific methods
module Protocol::Unreal
    private

    # Sends the initial data to the server
    def send_handshake
        send_pass
        send_protoctl
        send_server
        send_netinfo
    end

    # PASS :link password
    def send_pass
        raw "PASS :#{@config.send_password}"
    end

    # PROTOCTL protocol options
    def send_protoctl
        raw "PROTOCTL NOQUIT NICKv2 VHP SJOIN SJOIN2 SJ3 CLK"
    end

    # SERVER server.name 1 :server description
    def send_server
        # Keep track of our own server, it counts!
        Server.new($config.me.name, $config.me.description)

        raw "SERVER #{$config.me.name} 1 :#{$config.me.description}"
    end

    # EOS
    def send_eos
        raw "EOS"
    end

    # NETINFO maxglobal currenttime protocolversion cloakhash 0 0 0 :networkname
    def send_netinfo
        raw "NETINFO 0 #{Time.now.to_i} * 0 0 0 :#{@config.network}"
    end

    # PONG source :destination
    def send_pong(param)
        assert { { :param => String } }

        raw "PONG #{$config.me.name} :#{param}"
    end

    # NICK nick hops timestamp username hostname server servicestamp usermodes
    #      virtualhost :realname
    def send_nick(nick, user, host, real, modes)
        ts = Time.now.to_i

        str  = "NICK #{nick} 1 #{ts} #{user} #{host} #{$config.me.name} 0 "
        str += "+#{modes} #{host} :#{real}"

        raw str

        s = $servers[$config.me.name]
        User.new(nil, nick, user, host, real, modes, ts)
    end

    # :server.name SJOIN timestamp channel +modes[ modeparams] :memberlist
    def send_sjoin(target, timestamp, nick)
        assert { { :target => String, :timestamp => Fixnum, :nick => String } }

        raw ":#{$config.me.name} SJOIN #{timestamp} #{target} + :@#{nick}"
    end

    # :origin MODE target mode
    def send_mode(origin, target, mode)
        assert { { :origin => String, :target => String, :mode => String } }

        if origin
            raw "MODE #{target} #{mode}"
        else
            raw ":#{origin} MODE #{target} #{mode}"
        end
    end

    # :origin WALLOPS :message
    def send_operwall(origin, message)
        assert { { :origin => String, :message => String } }

        raw ":#{origin} WALLOPS :#{message}"
    end
end
