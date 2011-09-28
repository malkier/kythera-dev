# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/unreal/channel.rb: UnrealIRCd-specific Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This subclasses the base Channel class in `kythera/channel.rb`
class Protocol::Unreal::Channel < Channel
    # Unreal has all sorts of crazy channel modes
    @@status_modes = { 'q' => :owner,
                       'a' => :admin,
                       'o' => :operator,
                       'h' => :halfop,
                       'v' => :voice }

    @@list_modes   = { 'b' => :ban,
                       'e' => :except,
                       'I' => :invex }

    @@param_modes  = { 'f' => :flood_protection,
                       'j' => :join_throttle,
                       'k' => :keyed,
                       'l' => :limited,
                       'L' => :limit_channel }

    @@bool_modes   = { 'A' => :admin_only,
                       'c' => :no_ansi,
                       'C' => :no_ctcp,
                       'G' => :censored,
                       'i' => :invite_only,
                       'M' => :registered_moderated,
                       'm' => :moderated,
                       'N' => :no_nick_changes,
                       'n' => :no_external,
                       'O' => :ircops_only,
                       'p' => :private,
                       'Q' => :no_kick,
                       'r' => :registered,
                       'R' => :registered_only,
                       'S' => :strip_colors,
                       's' => :secret,
                       't' => :topic_lock,
                       'T' => :no_notice,
                       'u' => :auditorium,
                       'V' => :no_invite,
                       'z' => :ssl_only }

    # The channel's timestamp
    attr_reader :timestamp

    # Creates a new channel and adds it to the list keyed by name
    def initialize(name, timestamp = nil)
        @timestamp = (timestamp || Time.now).to_i
        super(name)
    end

    public

    # Is this hostmask in the except list?
    #
    # @param [String] hostmask the hostmask to check for
    # @return [True, False]
    #
    def is_excepted?(hostmask)
        assert { { :hostmask => String } }

        @list_modes[:except].include?(hostmask)
    end

    # Is this hostmask in the invex list?
    #
    # @param [String] hostmask the hostmask to check for
    # @return [True, False]
    #
    def is_invexed?(hostmask)
        assert { { :hostmask => String } }

        @list_modes[:invex].include?(hostmask)
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
end
