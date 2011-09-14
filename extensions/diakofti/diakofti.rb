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

        puts "Diakofti extension loaded (version #{VERSION})"
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

        def read
            begin
                @recvq = @socket.read_nonblock(8192)
            rescue Errno::EAGAIN
                return # Will go back to select and try again
            rescue Exception => err
                @socket.close
                $extension_sockets.delete(self)
            else
                parse
            end
        end

        def parse
           puts "got data: #{@recvq}"
        end
    end
end
