#
# kythera: services for IRC networks
# lib/kythera/protocol/inspircd/channel.rb: InspIRCd-specific Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This subclasses the base Channel class in `kythera/channel.rb`
class Protocol::InspIRCd::Channel < Channel
    # InspIRCd has all sorts of crazy channel modes
    @@status_modes = { 'a' => :protected,
                       'h' => :halfop,
                       'o' => :operator,
                       'q' => :owner,
                       'v' => :voice }

    @@list_modes   = { 'b' => :ban,
                       'e' => :except,
                       'g' => :chanfilter,
                       'I' => :invex }

    @@param_modes  = { 'l' => :limited,
                       'k' => :keyed,
                       'f' => :flood_protection,
                       'F' => :nick_flood,
                       'j' => :join_flood,
                       'J' => :kick_rejoin_protection,
                       'L' => :redirect }

    @@bool_modes   = { 'i' => :invite_only,
                       'm' => :moderated,
                       'n' => :no_external,
                       'p' => :private,
                       's' => :secret,
                       't' => :topic_lock,
                       'A' => :allow_invite,
                       'B' => :block_caps,
                       'c' => :block_color,
                       'C' => :no_ctcp,
                       'D' => :delay_join,
                       'G' => :censor,
                       'K' => :knock,
                       'R' => :registered_only,
                       'S' => :strip_color,
                       'T' => :no_notice,
                       'u' => :auditorium,
                       'y' => :oper_prefix,
                       'z' => :ssl_only }

    # The channel's timestamp
    attr_reader :timestamp

    # Creates a new channel and adds it to the list keyed by name
    def initialize(name, timestamp=nil)
        @name      = name
        @timestamp = (timestamp || Time.now).to_i

        # Keyed by UID
        @members = IRCHash.new

        clear_modes

        $log.error "new channel #{@name} already exists!" if $channels[name]

        $channels[name] = self

        $log.debug "new channel: #{@name} (#{timestamp})"

        $eventq.post(:channel_added, self)
    end

    public

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
