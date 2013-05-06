# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/run.rb: start up operations
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

class Kythera
    # Gets the ball rolling...
    def initialize
        puts "#{ME}: version #{VERSION} [#{RUBY_PLATFORM}]"

        # Record start time (for Protocol::P10)
        $state.start_time = Time.now

        # Run through some startup tests
        check_for_root
        check_ruby_version

        # Handle some signals
        trap(:HUP)  { rehash }
        trap(:INT)  { $eventq.post(:exit, 'received interruption signal') }
        trap(:TERM) { $eventq.post(:exit, 'received termination signal')  }

        # Some defaults for state
        logging  = true
        debug    = false
        wd       = Dir.getwd
        $uplink  = nil

        # Are we running on a platform that doesn't have fork?
        if RUBY_PLATFORM =~ /win32/i or RUBY_PLATFORM =~ /java/i
            willfork = false
        else
            willfork = true
        end

        # Do command-line options
        opts = OptionParser.new

        d_desc = 'Enable debug logging'
        h_desc = 'Display usage information'
        n_desc = 'Do not fork into the background'
        q_desc = 'Disable regular logging'
        v_desc = 'Display version information'

        opts.on('-d', '--debug',   d_desc) { debug    = true  }
        opts.on('-h', '--help',    h_desc) { puts opts; abort }
        opts.on('-n', '--no-fork', n_desc) { willfork = false }
        opts.on('-q', '--quiet',   q_desc) { logging  = false }
        opts.on('-v', '--version', v_desc) { abort            }

        begin
            opts.parse(*ARGV)
        rescue OptionParser::ParseError => err
            puts err, opts
            abort
        end

        # Logging stuff
        if debug
            $-w = true
            logging = true
            $config.me.logging = :debug
            Thread.abort_on_exception = true

            puts "#{ME}: warning: debug mode enabled"
            puts "#{ME}: warning: all activity will be logged in the clear"
            puts "#{ME}: warning: performance will be significantly impacted"
        end

        Log.logger = nil unless logging

        # Are we already running?
        check_running

        # Time to fork...
        if willfork
            daemonize(wd)
            Log.logger = Logger.new('var/kythera.log', 'weekly') if logging
        else
            puts "#{ME}: pid #{Process.pid}"
            puts "#{ME}: running in foreground mode from #{wd}"

            # Foreground logging
            Log.logger = Logger.new($stdout) if logging
        end

        Log.log_level = $config.me.logging if logging
        $db.loggers << $log if debug

        # Write a pid file
        open('var/kythera.pid', 'w') { |f| f.puts Process.pid }

        # Enter the main event loop
        begin
            exiting = catch(:exit) { main_loop }
        rescue Exception => err
            # Make the backtrace prettier, even though the code is ugly
            bt = err.backtrace.collect do |stacklevel|
                li = stacklevel.split(File::SEPARATOR)

                if li.include?('lib')
                    li[(li.rindex('kythera') + 1) .. -1].join(File::SEPARATOR)
                else
                    li.join(File::SEPARATOR)
                end
            end

            # Log the error and the full backtrace
            $log.fatal("unhandled exception: #{err}")
            $log.fatal("backtrace:\n\t\t\t#{bt.join("\n\t\t\t")}")

            # Exit cleanly
            exit_app
        end

        # We only get here if something did a `throw :exit`
        $log.info "shutting down: #{exiting}"

        # Exit cleanly
        exit_app
    end

    private

    # Runs the entire event-based app
    #
    # Once we enter this loop we only leave it to exit the app.
    # This makes sure we're connected and handles events, timers, and I/O
    #
    def main_loop
        exiting = false

        loop do
            # If it's true we're connectED, if it's nil we're connectING
            connect until $uplink and $uplink.connected?

            # Run the event loop until it's empty
            begin
                # Run the eventq to clear out socket events and bail
                if exiting
                    $eventq.run
                    throw :exit, exiting
                else
                    # Keep an eye out for graceful exit
                    exiting = catch(:exit) { $eventq.run }
                end
            rescue Uplink::DisconnectedError => err
                host = $uplink.config.host
                port = $uplink.config.port

                $log.error "disconnected from #{host}:#{port}: #{err}"
                $uplink.connected = false
            end

            # Sockets to check for waiting data
            readfds = []

            # Sockets to check for writability
            writefds = []

            # Add the extension sockets to the mix
            $extension_sockets.each do |es|
                readfds << es.socket if es.need_read?
            end

            $extension_sockets.each do |es|
                writefds << es.socket if es.need_write?
            end

            # Always check for read, and check for write when needed
            readfds  << $uplink.socket
            writefds << $uplink.socket if $uplink.need_write?

            # Ruby's threads suck. In theory, the timers should
            # manage themselves in separate threads. Unfortunately,
            # Ruby has a global lock and the scheduler isn't great, so
            # this tells select() to time out when the next timer needs to run.
            #
            timeout = Timer.next_time
            timeout = 1 if timeout  < 0
            timeout = 5 if timeout == 0

            # Wait up to 5 seconds for our socket to become readable/writable
            ret = IO.select(readfds, writefds, [], timeout)

            if ret
                # Readable sockets
                ret[0].each do |socket|
                   if socket == $uplink.socket
                       $eventq.post(:uplink_readable)
                   else
                       $eventq.post(:extension_socket_readable, socket)
                   end
                end

                # Writable sockets
                ret[1].each do |socket|
                    if socket == $uplink.socket
                        $eventq.post(:uplink_writable)
                    else
                        $eventq.post(:extension_socket_writable, socket)
                    end
                end
            end
        end
    end

    # Connects to the uplink
    def connect
        # Clear all non-persistent Timers
        Timer.stop_all

        # Reset all the things that are uplink-dependent
        $users.clear
        Channel.channels.clear
        $servers.clear
        $services.clear

        if $uplink
           $log.debug "current uplink failed, trying next"

            curruli   = $config.uplinks.find_index($uplink.config)
            curruli ||= 0
            curruli  += 1
            curruli   = 0 if curruli > ($config.uplinks.length - 1)

            $eventq.clear
            $uplink = Uplink.new($config.uplinks[curruli])

            sleep $config.me.reconnect_time
        else
            $eventq.clear
            $uplink = Uplink.new($config.uplinks.first)
        end

        begin
            $uplink.connect
        rescue Uplink::DisconnectedError => err
            host = $uplink.config.host
            port = $uplink.config.port
            $log.error "#{err} [#{host}:#{port}]"
        end
    end

    # Checks to see if we're running as root
    def check_for_root
        if Process.euid == 0
            puts "#{ME}: refuses to run as root"
            abort
        end
    end

    # Checks to see if we're running on a decent Ruby version
    def check_ruby_version
        if RUBY_VERSION > '1.9' and RUBY_VERSION < '1.9.2'
            puts "#{ME}: requires at least Ruby version 1.9.2"
            puts "#{ME}: you have #{RUBY_VERSION}"
            abort
        elsif RUBY_VERSION >= '1.9.2'
            Encoding.default_internal = 'UTF-8'
            Encoding.default_external = 'UTF-8'
        end
    end

    # Checks for an existing pid file and running daemon
    def check_running
        return unless File.exists? 'var/kythera.pid'

        currpid = File.read('var/kythera.pid').chomp.to_i rescue nil
        running = Process.kill(0, currpid) rescue nil

        if not running or currpid == 0
            File.delete 'var/kythera.pid'
        else
            puts "#{ME}: daemon is already running"
            abort
        end
    end

    # Forks into the background and exits the parent
    #
    # @param [String] wd the directory to move into once forked
    #
    def daemonize(wd)
        assert { { :wd => String } }

        begin
            pid = fork
        rescue Exception => err
            puts "#{ME}: unable to daemonize: #{err}"
            abort
        end

        # This is the parent process
        if pid
            puts "#{ME}: pid #{pid}"
            puts "#{ME}: running in background mode from #{Dir.getwd}"
            exit
        end

        # This is the child process
        Dir.chdir(wd)
    end

    # Cleans up before exiting
    def exit_app
        $log.close if $log
        File.delete 'var/kythera.pid'
        exit!
    end
end
