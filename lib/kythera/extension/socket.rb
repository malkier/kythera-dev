# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
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

        # Call #read if we have data on the socket
        $eventq.persistently_handle(:extension_socket_readable) do |socket|
            read if socket == @socket
        end

        # Call #write_sendq if we have data waiting to be written
        $eventq.persistently_handle(:extension_socket_writable) do |socket|
            write_sendq if socket == @socket
        end

        # Call #parse if we have read data available for processing
        $eventq.persistently_handle(:extension_socket_recvq_ready) do |socket|
            parse if socket == @socket
        end

        # Close up shop if we've been declared dead
        $eventq.persistently_handle(:extension_socket_dead) do |socket|
            if socket == @socket
                # Try to write anything in the sendq
                write_sendq unless @sendq.empty?

                # Close it and free it up for garbage collection
                @socket.close
                $extension_sockets.delete(self)
            end
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

    # We provide a basic read method, but the extension is free to override it
    def read
        begin
            @recvq << @socket.read_nonblock(8192)
        rescue Errno::EAGAIN
            return # Will go back to select and try again
        rescue Exception => err
            $log.debug "extension socket: lost client: #{self.to_s}"

            @socket.close
            $extension_sockets.delete(self)
        else
            $eventq.post(:extension_socket_recvq_ready, @socket)
        end
    end

    # This is just a prettier way to add to the sendq
    def write(data)
        @sendq << data
    end

    # We provide a basic write method, but the extension is free to override it
    def write_sendq
        while data = @sendq.first
            begin
                @socket.write_nonblock(data)
            rescue Errno::EAGAIN
                return # Will go back to select and try again
            rescue Exception => err
                $log.error "write error in extension socket #{to_s}: #{err}"
                @socket.close
                $extension_sockets.delete(self)
            else
                $log.debug "#{self.to_s} <- #{@sendq.shift}"
            end
        end
    end

    def parse
        $log.error "an extension forgot to override Extension::Socket#parse"
    end
end
