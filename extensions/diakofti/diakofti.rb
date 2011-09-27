# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# extensions/diakofti/diakofti.rb: external API
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

class Diakofti; end

require 'extensions/diakofti/commands'
require 'extensions/diakofti/send'

require 'json'
require 'syck'
require 'socket'
require 'yaml'

class Diakofti
    # Backwards-incompatible changes
    V_MAJOR = 0

    # Backwards-compatible changes
    V_MINOR = 0

    # Minor changes and bugfixes
    V_PATCH = 1

    # String representation of our version..
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    attr_reader :config

    def initialize(config)
        @config = config

        if @config.bind
            sock = TCPServer.new(@config.bind, @config.port)
        else
            sock = TCPServer.new(@config.port)
        end

        @socket = Server.new(sock, self)

        $log.debug "Diakofti extension loaded (version #{VERSION})"
    end

    class Server < Extension::Socket
        def initialize(socket, diakofti)
            super(socket)

            @diakofti = diakofti
        end

        private

        def read
            begin
                newsock = @socket.accept_nonblock
            rescue Errno::EAGAIN
                return # Will go back to select and try again
            else
                $log.info "diakofti: new client from #{newsock.peeraddr[3]}"
                Client.new(newsock, @diakofti)
            end
        end
    end

    class Client < Extension::Socket
        include Diakofti::Senders
        include Diakofti::CommandHandlers

        def initialize(socket, diakofti)
            super(socket)

            @diakofti    = diakofti
            @remote_host = @socket.peeraddr[3]
            @protocol    = :yaml
            @state       = OpenStruct.new
            @uuid        = nil
        end

        public

        def to_s
            "Diakofti::Client:#{@remote_host}"
        end

        def need_read?
            !! @socket
        end

        private

        def write_sendq
            @sendq.collect! { |e| e.send("to_#{@protocol}") }

            if @protocol == :yaml
                @sendq.collect! { |e| e.sub!('--- ', '') }
            end

            super
        end

        def parse
            while stanza = @recvq.shift
                stanza.chomp!
                $log.debug "#{self.to_s} -> #{stanza}"

                begin
                    if @protocol == :yaml
                        stanza = YAML.load(stanza)
                    elsif @protocol == :json
                        stanza = JSON.load(stanza)
                    end
                rescue Exception
                    # If we haven't started yet, and it failed to parse, try
                    # parsing it with JSON before dying
                    unless @state.start
                        begin
                            stanza = JSON.load(stanza)
                        rescue Exception
                            send_error('not-well-formed')
                            return
                        end
                    else
                        send_error("#{@protocol}-not-well-formed")
                        return
                    end
                end

                next unless stanza and not stanza.empty?

                next if stanza == '---' and not @state.start

                if stanza == '...'
                    $log.info "diakofti: #{@remote_host} ended the session"
                    @sendq << '...'
                    $eventq.post(:extension_socket_dead, @socket)
                    return
                end

                unless stanza.kind_of?(Hash)
                    send_error('invalid-request')
                    next
                end

                # Dispatch it to our handlers
                stanza.each do |command, args|
                    unless args
                        errargs = { 'command' => command }
                        send_error('invalid-arguments', errargs)
                        next
                    end

                    cmd = "do_#{command}"

                    if self.respond_to?(cmd, true)
                        self.send(cmd, OpenStruct.new(args))
                    else
                        errargs = { 'command' => command }
                        send_error('unknown-command', errargs )
                    end
                end
            end
        end
    end
end

class Hash
    def to_yaml_style
        :inline
    end
end

class Array
    def to_yaml_style
        :inline
    end
end
