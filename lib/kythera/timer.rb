# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/timer.rb: execute code at certain times
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# Allows us to execute a block of code at certain times
class Timer
    # A list of all running timers
    @@timers = []

    # instance attributes
    attr_reader :time, :timeout, :repeat, :persist

    # Creates a new timer to be executed within 10 seconds of +time+.
    #
    # @param [Fixnum] time time in seconds
    # @param [True, False] repeat keep executing every 'time' seconds?
    # @param [True, False] persist keep the timer around through disconnections?
    # @param [Proc] block the code block to execute
    #
    def initialize(time, repeat = false, persist = false, &block)
        @time    = time.to_i
        @timeout = Time.now.to_f + @time
        @repeat  = repeat
        @persist = persist
        @block   = block

        @@timers << self

        @thread = Thread.new { start }

        self
    end

    public

    # Alias for new, sets up the block to repeat by default
    #
    # @param [Fixnum] time how often to repeat, in seconds
    # @param [Proc] block the code block to execute
    #
    def Timer.every(time, &block)
        new(time, true, false, &block)
    end

    # Alias for new, sets up the block to not repeat by default
    #
    # @param [Fixnum] time how long to wait, in seconds
    # @param [Proc] block the code block to execute
    #
    def Timer.after(time, &block)
        new(time, false, false, &block)
    end

    # Alias for new, sets up the block to repeat and persist by default
    #
    # @param [Fixnum] time how often to repeat, in seconds
    # @param [Proc] block the code block to execute
    #
    def Timer.persist_every(time, &block)
        new(time, true, true, &block)
    end

    # Alias for new, sets up the block to not repeat but persist by default
    #
    # @param [Fixnum] time how long to wait, in seconds
    # @param [Proc] block the code block to execute
    #
    def Timer.persist_after(time, &block)
        new(time, false, true, &block)
    end

    # Stops all timers
    def Timer.stop
        @@timers.each { |t| t.stop }
    end

    # Kills the thread we're in
    def stop
        return if @persist

        @@timers.delete(self)
        @thread.exit
    end

    private

    # Executes the timer
    def start
        loop do
            # Wait to call our code
            sleep(@time)

            # Call it
            @block.call

            # Do we need to repeat?
            if @repeat
                @timeout = Time.now.to_f + @time
            else
                break
            end
        end

        # If the loop is over that means our timer is done
        @@timers.delete(self)
    end
end
