# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6/channel.rb: TS6-specific Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# This subclasses the base Channel class in `kythera/channel.rb`
class Protocol::TS6::Channel < Channel
    # TS6 has except and invex as well as ban
    @@list_modes = { 'b' => :ban,
                     'e' => :except,
                     'I' => :invex }

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
end
