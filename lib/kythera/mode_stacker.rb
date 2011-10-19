# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/mode_stacker.rb: performs mode stacking
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# Stacks modes to be sent to the uplink at once
#
# Instead of 10 calls to `Protocol#channel_mode` sending 10
# separate MODE commands to the uplink, this class helps them
# stack up to send many modes at once. How many exactly depends
# on the uplink protocol.
#
class ModeStacker
    # Keyed by channel name
    @@mode_stacks = IRCHash.new

    # Find a ModeStacker object by the channel name
    #
    # @param [String] name channel name
    # @return [ModeStacker, nil] the matching ModeStacker, or nil
    #
    def self.find_by_channel(name)
        assert { { :name => String } }
        @@mode_stacks[name]
    end

    def initialize(user, channel, action = nil, modes = [], params = [])
        assert { :channel }
        assert { :user    } if user

        @add_modes  = []
        @add_params = []
        @channel    = channel
        @del_modes  = []
        @del_params = []
        @timer      = nil
        @user       = user

        @@mode_stacks[@channel.name] = self

        stack_modes(action, modes, params) if action and not modes.empty?
    end

    private

    # Get the total length of our pending modes
    #
    # @return [Integer] total length of our pending modes
    #
    def modes_length
        @add_modes.length + @del_modes.length
    end

    # Format our modes into a form suitable for IRC
    #
    # @return [Array] IRC-formatted mode string and param string
    #
    def format_modes
        modes, params  = '', []

        # Do add modes
        unless @add_modes.empty?
            amodes  = @add_modes.collect { |m| Channel.cmodes[m] }.join('')
            params += @add_params
            modes  += "+#{amodes}"
        end

        # Do del modes
        unless @del_modes.empty?
            dmodes  = @del_modes.collect { |m| Channel.cmodes[m] }.join('')
            params += @del_params
            modes  += "-#{dmodes}"
        end

        # Format params
        params = params.join(' ')

        [modes, params]
    end

    # Process our modes in order to post suitable events
    def post_mode_events
        params = @add_params.dup

        @add_modes.each do |mode|
            param = nil
            param = params.shift if Channel.status_modes.values.include?(mode)
            param = params.shift if Channel.param_modes.values.include?(mode)

            $eventq.post(:mode_added_on_channel, mode, param, @channel)
        end

        params = @del_params.dup

        @del_modes.each do |mode|
            param = nil
            param = params.shift if Channel.status_modes.values.include?(mode)

            $eventq.post(:mode_deleted_on_channel, mode, param, @channel)
        end
    end

    # Send our modes to the uplink and get rid of ourselves
    def apply_modes
        origin    = @user ? @user.key : nil
        target    = @channel.name
        timestamp = @channel.timestamp

        modes, params = format_modes

        modestr = "#{modes} #{params}"

        # Keep state
        @channel.parse_modes(modes, params.split(' '))
        post_mode_events

        $uplink.send_channel_mode(origin, target, timestamp, modestr)

        @@mode_stacks.delete(@channel.name)
    end

    public

    # Add modes one-at-a-time until we hit the max modes this protocol
    # supports, then send them out. If we don't hit the max modes,
    # set a timer to send them out in 500ms in case we get more modes
    # to set in another call. This is ugly, but it is what it is.
    #
    # @param [Symbol] action :add or :del
    # @param [Array] modes the modes to add
    # @param [Array] params the params for the modes
    # @return [nil] nil
    #
    def stack_modes(action, modes, params = [])
        assert { { :action => Symbol, :modes => Array, :params => Array } }

        # If we have a timer, that means this is at least the second call here
        if @timer
            @timer.stop
            @timer = nil
        end

        until modes.empty?
            if modes_length >= $uplink.config.max_modes
                # Send it now, since we've hit the max modes
                apply_modes

                # Those modes are gone, so get a new blank one
                ModeStacker.new(@user, @channel, action, modes, params)

                # We're done, the new ModeStacker will handle the rest
                return nil
            else
                mode = modes.shift

                if action == :add
                    @add_modes << mode
                elsif action == :del
                    @del_modes << mode
                end

                # If it's add:
                #     If it's a status or param mode, strip off a param
                #
                # If it's del:
                #     If it's a status mode, strip off a param
                #     If the mode is :keyed, strip off a param
                #
                if action == :add
                    if Channel.status_modes.values.include?(mode)
                        @add_params << params.shift
                    elsif Channel.param_modes.values.include?(mode)
                        @add_params << params.shift
                    end
                elsif action == :del
                    if Channel.status_modes.values.include?(mode)
                        @del_params << params.shift
                    elsif mode == :keyed
                        param = params.shift

                        # If they passed us a param, use that
                        if param
                            @del_params << param

                        # If not, grab the actual key from the channel
                        else
                            @del_params << @channel.mode_param(:keyed)
                        end
                    end
                end
            end
        end

        # Loop is over, modes are empty; either send or timer
        if modes_length >= $uplink.config.max_modes
            apply_modes
        else
            # Set a timer so that we can stack additional modes if they come in
            @timer = Timer.after(0.5) { apply_modes }
        end

        return nil
    end
end
