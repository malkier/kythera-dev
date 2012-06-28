# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/channel.rb: Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# This is just a base class; protocol module should subclass this
class Channel
    # A list of all channels; keyed by channel name by default
    @@channels = IRCHash.new

    # Standard IRC status cmodes
    @@status_modes = { 'o' => :operator,
                       'v' => :voice }

    # Standard IRC list cmodes
    @@list_modes   = { 'b' => :ban }

    # Standard IRC cmodes requiring a param
    @@param_modes  = { 'l' => :limited,
                       'k' => :keyed }

    # Standard boolean IRC cmodes
    @@bool_modes   = { 'i' => :invite_only,
                       'm' => :moderated,
                       'n' => :no_external,
                       'p' => :private,
                       's' => :secret,
                       't' => :topic_lock }

    # Look up a channel in the global list
    def self.[](index); @@channels[index]; end

    # Attribute reader for `@@channels`
    def self.channels; @@channels; end

    # Attribute reader for `@@status_modes`
    def self.status_modes; @@status_modes; end

    # Attribute reader for `@@list_modes`
    def self.list_modes; @@list_modes; end

    # Attribute reader for `@@param_modes`
    def self.param_modes; @@param_modes; end

    # Attribute reader for `@@bool_modes`
    def self.bool_modes; @@bool_modes; end

    # Attribute reader for `@@cmodes`
    def self.cmodes; @@cmodes; end

    # The channel name, including prefix
    attr_reader :name

    # A Hash of members keyed by nickname
    attr_reader :members

    # The channel's timestamp
    attr_reader :timestamp

    # Creates a new channel; can be extended by the protocol module
    def initialize(name, timestamp = nil)
        assert { { :name => String } }

        @name      = name
        @timestamp = (timestamp || Time.now).to_i

        # Keyed by nickname by default
        @members = IRCHash.new

        clear_modes
        setup_cmodes

        @@channels[name] = self

        $log.debug "new channel: #{@name}"

        $eventq.post(:channel_added, self)
    end

    public

    # String representation is just `@name`
    def to_s
        @name
    end

    # Writer for `@timestamp`
    #
    # @param timestamp new timestamp
    #
    def timestamp=(timestamp)
        if timestamp.to_i > @timestamp
            $log.warn "changing timestamp to a later value?"
            $log.warn "#{@name} -> #{timestamp} > #{@timestamp}"
        end

        $log.debug "#{@name}: timestamp changed: #{@timestamp} -> #{timestamp}"

        @timestamp = timestamp.to_i
    end

    # Parses a mode string and updates channel state
    #
    # @param [String] modes the mode string
    # @param [Array] params params to the mode string, tokenized by space
    #
    def parse_modes(modes, params)
        assert { { :modes => String, :params => Array } }

        action = nil # :add or :delete

        modes.each_char do |c|
            mode, param = nil

            if c == '+'
                action = :add
                next
            elsif c == '-'
                action = :delete
                next
            end

            # Status modes
            if mode = @@status_modes[c]
                param = params.shift
                parse_status_mode(action, mode, param)

            # List modes
            elsif mode = @@list_modes[c]
                param = params.shift

                if action == :add
                    @list_modes[mode] << param
                elsif action == :delete
                    @list_modes[mode].delete(param)
                end

            # Has a param when +, doesn't when -
            elsif mode = @@param_modes[c]
                if action == :add
                    param = params.shift
                    @modes << mode
                    @param_modes[mode] = param
                elsif action == :delete
                    @modes.delete(mode)
                    @param_modes.delete(mode)
                end

            # The rest, no param
            elsif mode = @@bool_modes[c]
                if action == :add
                    @modes << mode
                elsif action == :delete
                    @modes.delete(mode)
                end
            end

            if mode
                # Post an event for it
                if action == :add
                    $eventq.post(:mode_added_on_channel, mode, param, self)
                elsif action == :delete
                    $eventq.post(:mode_deleted_on_channel, mode, param, self)
                end

                $log.debug "mode #{action}: #{self} -> #{mode} #{param}"
            end
        end
    end

    # Adds a User as a member
    #
    # @param [User] user the User to add
    #
    def add_user(user)
        assert { :user }

        @members[user.key] = user
        user.channels << self

        $log.debug "user joined #{self}: #{user} (#{@members.length})"

        $eventq.post(:user_joined_channel, user, self)
    end

    # Deletes a User as a member
    #
    # @param [User] user User object to delete
    #
    def delete_user(user)
        assert { :user }

        @members.delete(user.key)
        user.channels.delete(self)

        user.status_modes.delete(self)

        $log.debug "user parted #{self}: #{user} (#{@members.length})"

        $eventq.post(:user_parted_channel, user, self)

        if @members.length == 0
            @@channels.delete(@name)

            $log.debug "removing empty channel #{self}"

            $eventq.post(:channel_deleted, self)
        end
    end

    # Does this channel have the specified mode set?
    #
    # @param [Symbol] mode the mode symbol
    # @return [True, False]
    #
    def has_mode?(mode)
        assert { { :mode => Symbol } }

        @modes.include?(mode) || @param_modes.include?(mode)
    end

    # Get a mode's param
    #
    # @param [Symbol] mode the mode symbol
    # @return [String] the mode param's value
    #
    def mode_param(mode)
        assert { { :mode => Symbol } }

        @param_modes[mode]
    end

    # Get a list mode's list
    #
    # @param [Symbol] mode the mode symbol
    # @return [Array] the list
    #
    def mode_list(mode)
        assert { { :mode => Symbol } }

        @list_modes[mode]
    end

    # Is this hostmask in the ban list?
    #
    # @param [String] hostmask the hostmask to check for
    # @return [True, False]
    #
    def is_banned?(hostmask)
        assert { { :hostmask => String } }

        @list_modes[:ban].include?(hostmask)
    end

    # Deletes all modes
    def clear_modes
        @modes       = []
        @param_modes = {}
        @list_modes  = {}

        @@list_modes.each_value do |mode|
            @list_modes[mode] = []
        end
    end

    private

    # Sets up a list of all cmodes
    def setup_cmodes
        @@cmodes = [@@status_modes, @@list_modes, @@param_modes, @@bool_modes]
        @@cmodes = @@cmodes.inject(:merge)
        @@cmodes.update(@@cmodes.invert)
    end

    # Deals with status modes
    #
    # @param [Symbol] action :add or :del
    # @param [Symbol] mode Symbol representing a mode flag
    # @param [String] target the user this mode applies to
    #
    def parse_status_mode(action, mode, target)
        assert { { :action => Symbol, :mode => Symbol, :target => String } }

        unless user = $users[target]
            $log.warn "cannot parse a status mode for an unknown user"
            $log.warn "#{target} -> #{mode} (#{self})"

            return
        end

        if action == :add
            user.add_status_mode(self, mode)
        elsif action == :delete
            user.delete_status_mode(self, mode)
        end
    end
end
