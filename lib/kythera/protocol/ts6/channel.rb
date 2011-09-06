#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6/channel.rb: TS6-specific Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This reopens the base Channel class in `kythera/channel.rb`
class Channel
    # TS6 has except and invex as well as ban
    @@list_modes = { 'b' => :ban,
                     'e' => :except,
                     'I' => :invex }

    # The channel's timestamp
    attr_reader :timestamp

    # Creates a new channel and adds it to the list keyed by name
    def initialize(name, timestamp=nil)
        @name      = name
        @timestamp = (timestamp || Time.now).to_i
        @modes     = []

        # Keyed by UID
        @members = IRCHash.new

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
