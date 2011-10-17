# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/uplink.rb: represents the interface to the remote IRC server
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# The current uplink; it's a global because extensions etc need it
$uplink = nil

# Represents the interface to the remote IRC server
class Uplink
    # An exception we raise when disconnected
    class DisconnectedError < Exception
    end

    # The configuration information
    attr_accessor :config

    # Are we connected?
    attr_accessor :connected

    # The TCPSocket
    attr_reader :socket

    # Creates a new Uplink and includes the protocol-specific methods
    def initialize(config)
        @config    = config
        @connected = false
        @recvq     = []
        @sendq     = []
        @socket    = nil

        # Set up some event handlers
        $eventq.handle(:uplink_readable) { read  }
        $eventq.handle(:uplink_writable) { write }
        $eventq.handle(:uplink_parsable) { parse }

        $eventq.handle(:connected) { send_handshake      }
        $eventq.handle(:connected) { Service.instantiate }

        $eventq.handle(:end_of_burst) do |delta|
            $log.info "finished synching to network in #{delta}s"
        end

        unless @config.casemapping_override
            case @config.protocol
            when :p10
                @config.max_modes   = 6
                @config.casemapping = :rfc1459
            when :unreal
                @config.max_modes   = 6
                @config.casemapping = :ascii
            else
                @config.max_modes   = 4
                @config.casemapping = :rfc1459
            end
        end

        # Include the methods for the protocol we're using
        extend Protocol
        extend Protocol.find(@config.protocol)
    end

    public

    # Represents the Uplink as a String
    #
    # @return [String] name:port
    #
    def to_s
        "#{self.class}:#{@config.name}"
    end

    # Returns the Uplink name from configuration
    #
    # @return [String] Uplink's name in the configuration file
    #
    def name
        @config.name
    end

    # Returns the Uplink port from configuration
    #
    # @return [Fixnum] Uplink's port in the configuration file
    #
    def port
        @config.port
    end

    # Returns whether we're connected or not
    #
    # @return [True, False]
    #
    def connected?
        @connected
    end

    # Returns whether the sendq needs written
    #
    # @return [True, False]
    #
    def need_write?
        not @sendq.empty?
    end

    # Connects to the uplink using the information in `@config`
    def connect
        $log.info "connecting to #{@config.host}:#{@config.port}"

        begin
            @socket = TCPSocket.new(@config.host, @config.port,
                                    @config.bind_host, @config.bind_port)

            start_tls if @config.ssl
        rescue Exception => err
            raise DisconnectedError, err
        else
            $log.info "connected to #{@config.name}:#{@config.port}"
            @connected = true
            $eventq.post(:connected)
        end
    end

    # Matches CR or LF
    CR_OR_LF = /\r|\n/

    # Reads waiting data from the socket and stores each "line" in the recvq
    def read
        begin
            data = @socket.read_nonblock(8192)
        rescue Errno::EAGAIN
            return # Will go back to select and try again
        rescue Exception => err
            raise DisconnectedError, err
        end

        raise DisconnectedError, "empty read" if not data or data.empty?

        # Passes every "line" to the block, including "\n"
        data.scan /(.+\n?)/ do |line|
            line = line.first

            # If the last line had no \n, add this one onto it.
            if @recvq[-1] and @recvq[-1][-1].chr !~ CR_OR_LF
                @recvq[-1] += line
            else
                @recvq << line
            end
        end

        if @recvq[-1] and @recvq[-1][-1].chr == "\n"
            $eventq.post(:uplink_parsable)
        end
    end

    # Writes the each "line" in the sendq to the socket
    def write
        while line = @sendq.first
            $log.debug "<- #{line}"
            line += "\r\n"

            begin
                @socket.write_nonblock(line)
            rescue Errno::EAGAIN
                return # Will go back to select and try again
            rescue Exception => err
                raise DisconnectedError, err
            else
                @sendq.shift
            end
        end
    end

    private

    # Removes the first character from a string
    NO_COL = 1 .. -1

    # Because String#split treats ' ' as /\s/ for some reason
    # XXX - This sucks; it slows down the parser by quite a lot
    RE_SPACE = / /

    # Parses incoming IRC data and sends it off to protocol-specific handlers
    def parse
        while line = @recvq.shift
            line.chomp!

            $log.debug "-> #{line}"

            # don't do anything if the line is empty
            next if line.empty?

            if line[0].chr == ':'
                # Remove the origin from the line, and eat the colon
                origin, line = line.split(RE_SPACE, 2)
                origin = origin[NO_COL]
            elsif @config.protocol == :p10
                # P10 doesn't prefix it's "origin" with a colon
                origin, line = line.split(RE_SPACE, 2)

                # Every command except these two have an origin
                if origin == "PASS" or origin == "SERVER"
                    line   = "#{origin} #{line}"
                    origin = nil
                end
            else
                origin = nil
            end

            tokens, args = line.split(' :', 2)
            parv = tokens.split(RE_SPACE)
            cmd  = parv.delete_at(0)
            parv << args unless args.nil?

            # P10 uses tokens for commands
            if @config.protocol == :p10
                token = Protocol::P10::Tokens[cmd.to_sym]
                cmd = token if token
            end

            # Downcase it and turn it into a Symbol
            cmd = "irc_#{cmd.to_s.downcase}".to_sym

            # Call the protocol-specific handler
            if self.respond_to?(cmd, true)
                self.send(cmd, origin, parv)
            else
                $log.debug "no protocol handler for #{cmd.to_s.upcase}"
            end

            # Fire off an event for extensions, etc
            $eventq.post(cmd, origin, parv)
        end

        true
    end

    # Set up and connect the SSL socket
    def start_tls
        ctx = OpenSSL::SSL::SSLContext.new

        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ctx.options     = OpenSSL::SSL::OP_NO_TICKET
        ctx.options    |= OpenSSL::SSL::OP_NO_SSLv2
        ctx.options    |= OpenSSL::SSL::OP_ALL

        socket = OpenSSL::SSL::SSLSocket.new(@socket, ctx)

        begin
            socket.connect
            socket.sync_close = true
        rescue Exception => err
            raise DisconnectedError, err
        else
            @socket = socket
        end
    end
end
