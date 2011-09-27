# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6/channel.rb: TS6-specific Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This subclasses the base Channel class in `kythera/channel.rb`
class Protocol::TS6::Channel < Channel
    # TS6 has except and invex as well as ban
    @@list_modes = { 'b' => :ban,
                     'e' => :except,
                     'I' => :invex }

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
    # @return [Boolean] true or false
    #
    def is_excepted?(hostmask)
        @list_modes[:except].include?(hostmask)
    end

    # Is this hostmask in the invex list?
    #
    # @param [String] hostmask the hostmask to check for
    # @return [Boolean] true or false
    #
    def is_invexed?(hostmask)
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
