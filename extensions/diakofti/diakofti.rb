#
# kythera: services for IRC networks
# extensions/diakofti/diakofti.rb: external API
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

require 'socket'

class Diakofti
    # Backwards-incompatible changes
    V_MAJOR = 0

    # Backwards-compatible changes
    V_MINOR = 0

    # Minor changes and bugfixes
    V_PATCH = 1

    # String representation of our version..
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    def initialize(config)
        @config = config

        return unless @config

        if @config.bind
            sock = TCPServer.new(@config.bind, @config.port)
        else
            sock = TCPServer.new(@config.port)
        end

        @socket = Server.new(sock)

        $log.debug "Diakofti extension loaded (version #{VERSION})"
    end

    class Server < Extension::Socket
        def initialize(socket)
            super
        end

        private

        def read
            begin
                newsock = @socket.accept_nonblock
            rescue Errno::EAGAIN
                return # Will go back to select and try again
            else
                Client.new(newsock)
            end
        end
    end

    class Client < Extension::Socket
        def initialize(socket)
            super
        end

        private

        def parse
           while line = @recvq.shift
               $log.debug "parsing: #{line}"
           end
        end
    end
end
