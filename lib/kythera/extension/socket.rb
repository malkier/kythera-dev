#
# kythera: services for IRC networks
# lib/kythera/extension/socket.rb: extensions socket interface
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# A list of all extension sockets
$extension_sockets = []

# A class that enables networking in the main loop
class Extension::Socket
    attr_reader :socket

    # Create a new socket that gets automatically handled in the main loop
    def initialize(socket)
        @recvq  = []
        @sendq  = []
        @socket = socket

        $eventq.persistently_handle(:extension_socket_readable) do |socket|
            read if socket == @socket
        end

        $eventq.persistently_handle(:extension_socket_writable) do |socket|
            write if socket == @socket
        end

        $extension_sockets << self
    end

    public

    # Do we need to read?
    #
    # @return [Boolean] true or false
    #
    def need_read?
        true
    end

    # Do we need to write?
    #
    # @return [Boolean] true or false
    #
    def need_write?
        not @sendq.empty?
    end

    private

    # The extension should override these
    def read
        $log.error "an extension forgot to override Extension::Socket#read"
    end

    def write
        $log.error "an extension forgot to override Extension::Socket#write"
    end
end
