#
# kythera: services for TSora IRC networks
# lib/kythera/protocol/ts6.rb: implements the TS6 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in LICENSE
#

# Implements TS6 protocol-specific methods
module Protocol::TS6
    private

    #################
    # S E N D E R S #
    #################

    # PASS <PASSWORD> TS <TS_CURRENT> :<SID>
    def send_pass
        @sendq << "PASS #{@config.send_password} TS 6 :#{@config.sid}"
    end

    def send_capab
        @sendq << 'CAPAB :QS KLN UNKLN ENCAP'
    end

    # SERVER <NAME> <HOPS> :<DESC>
    def send_server
        str  = 'SERVER '
        str += "#{Kythera.config.me.name} 1 :#{Kythera.config.me.description}"

        @sendq << str
    end

    # SVINFO <MAX_TS_VERSION> <MIN_TS_VERSION> 0 :<TS>
    def send_svinfo
        @sendq << "SVINFO 6 6 0 :#{Time.now.to_i}"
    end

    # :<SID> PONG <NAME> :<PARAM>
    def send_pong(param)
        @sendq << ":#{@config.sid} PONG #{Kythera.config.me.name} :#{param}"
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
    def receive_pass(origin, parv)
        if parv[0] != @config.receive_password.to_s
            log.error "incorrect password received from `#{@config.name}`"
            @recvq.clear
            @connection.close
        else
            Server.new(parv[3], '<unknown>', @logger)
        end
    end

    # Handles an incoming SERVER
    #
    # parv[0] -> server name
    # parv[1] -> hops
    # parv[2] -> server description
    #
    def receive_server(origin, parv)
        not_used, s   = Server.servers.first # There should only be one
        s.name        = parv[0]
        s.description = parv[2]
    end

    # Handles an incoming SVINFO
    #
    # parv[0] -> max ts version
    # parv[1] -> min ts version
    # parv[2] -> '0'
    # parv[3] -> current ts
    #
    def receive_svinfo(origin, parv)
        if parv[0].to_i < 6
            log.error "`#{@config.name}` doesn't support TS6"
            @recvq.clear
            @connection.close
        elsif (parv[3].to_i - Time.now.to_i) >= 60
            log.warning "`#{@config.name}` has excessive TS delta"
        end
    end

    # Handles an incoming PING
    #
    # parv[0] -> sid of remote server
    #
    def receive_ping(origin, parv)
        send_pong(parv[0])
    end
end
