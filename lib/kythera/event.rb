# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/event.rb: implements the event loop
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# Contains information about a posted event
class Event
    # The name of the event
    attr_reader :event

    # The arguments to pass to the handler
    attr_reader :args

    # Creates a new Event
    #
    # @param [Symbol] event unique event name
    # @param args the arguments to be passed to the handler
    #
    def initialize(event, *args)
        @event = event
        @args  = args
    end
end

# A queue of events, with handlers
class EventQueue
    # The list of Events
    attr_reader :queue

    # The list of code blocks
    attr_reader :handlers

    # Creates a new EventQueue
    def initialize
        @queue       = []
        @handlers    = {}
        @persistents = {}
    end

    public

    # Posts a new event to the queue to be handled
    #
    # @param [Symbol] event unique event name
    # @param args the arguments to be passed to the handler
    #
    def post(event, *args)
        @queue << Event.new(event, *args)
        #$log.debug "posted new event: #{event}"
    end

    # Registers a handler for an event
    #
    # @param [Symbol] event unique event name
    # @param [Proc] block the handling code
    #
    def handle(event, &block)
        (@handlers[event] ||= []) << block
        #$log.debug "registered handler for event: #{event}"
    end

    # Registers a handler for an event that persists
    #
    # @param [Symbol] event unique event name
    # @param [Proc] block the handling code
    #
    def persistently_handle(event, &block)
        (@persistents[event] ||= []) << block
        #$log.debug "registered persistent handler for event: #{event}"
    end

    # Does the queue need emptied?
    #
    # @return [True, False]
    #
    def needs_run?
        @queue.empty? ? false : true
    end

    # Clears non-persistent handlers
    def clear
        @handlers.clear
    end

    # Goes through the event queue and runs the handlers
    def run
        exiting = false

        while e = @queue.shift
            if e.event == :exit
                exiting = e

            elsif @handlers[e.event]
                #$log.debug "dispatching handlers for event: #{e.event}"
                @handlers[e.event].each { |block| block.call(*e.args) }

            elsif @persistents[e.event]
                #$log.debug "dispatching persistents for event: #{e.event}"
                @persistents[e.event].each { |block| block.call(*e.args) }

            else
                next # No handlers
            end
        end

        # Now we can run the exit handlers, and then we bubble back up to the
        # call to Kythera#main_loop for a graceful exit. Althought anything
        # that registered to handle :exit will run here, no events they add will
        # be run, and as a result no socket operations will work.
        if exiting
            if @handlers[:exit]
                @handlers[:exit].each    { |block| block.call(*exiting.args) }
            end

            if @persistents[:exit]
                @persistents[:exit].each { |block| block.call(*exiting.args) }
            end

            throw :exit, *exiting.args
        end
    end
end
