#
# kythera: services for TSora IRC networks
# lib/kythera/protocol/ts6.rb: implements the TS6 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in LICENSE
#

require 'kythera'

require 'kythera/protocol/ts6/server'
require 'kythera/protocol/ts6/user'

# Implements TS6 protocol-specific methods
module Protocol::TS6
    private

    #################
    # S E N D E R S #
    #################

    # Sends the initial data to the server
    def send_handshake
        send_pass
        send_capab
        send_server
        send_svinfo
    end

    # PASS <PASSWORD> TS <TS_CURRENT> :<SID>
    def send_pass
        @sendq << "PASS #{@config.send_password} TS 6 :#{@config.sid}"
    end

    # CAPAB :<CAPABS>
    def send_capab
        @sendq << 'CAPAB :QS KLN UNKLN ENCAP'
    end

    # SERVER <NAME> <HOPS> :<DESC>
    def send_server
        @sendq << "SERVER #{$config.me.name} 1 :#{$config.me.description}"
    end

    # SVINFO <MAX_TS_VERSION> <MIN_TS_VERSION> 0 :<TS>
    def send_svinfo
        @sendq << "SVINFO 6 6 0 :#{Time.now.to_i}"
    end

    # :<SID> PONG <NAME> :<PARAM>
    def send_pong(param)
        @sendq << ":#{@config.sid} PONG #{$config.me.name} :#{param}"
        @sendq << ":K!service@services.int PRIVMSG \#kythera :#{User.users.inspect}"
    end

    #####################
    # R E C E I V E R S #
    #####################

    # Handles an incoming PASS
    #
    # parv[0] -> password
    # parv[1] -> 'TS'
    # parv[2] -> ts version
    # parv[3] -> sid of remote server
    #
    def irc_pass(m)
        if m.parv[0] != @config.receive_password.to_s
            log.error "incorrect password received from `#{@config.name}`"
            @recvq.clear
            @connection.close
        else
            Server.new(m.parv[3], @logger)
        end
    end

    # Handles an incoming SERVER
    #
    # parv[0] -> server name
    # parv[1] -> hops
    # parv[2] -> server description
    #
    def irc_server(m)
        not_used, s   = Server.servers.first # There should only be one
        s.name        = m.parv[0]
        s.description = m.parv[2]
    end

    # Handles an incoming SVINFO
    #
    # parv[0] -> max ts version
    # parv[1] -> min ts version
    # parv[2] -> '0'
    # parv[3] -> current ts
    #
    def irc_svinfo(m)
        if m.parv[0].to_i < 6
            log.error "`#{@config.name}` doesn't support TS6"
            @recvq.clear
            @connection.close
        elsif (m.parv[3].to_i - Time.now.to_i) >= 60
            log.warning "`#{@config.name}` has excessive TS delta"
        end
    end

    # Handles an incoming PING
    #
    # parv[0] -> sid of remote server
    #
    def irc_ping(m)
        send_pong(m.parv[0])
    end

    # Handles an incoming UID
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
    def irc_uid(m)
        p = m.parv
        User.new(p[0], p[4], p[5], p[6], p[8], p[7], p[2], @logger)
    end
end
