# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
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

    @@param_modes  = { 'k' => :keyed,
                       'l' => :limited,
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

    public

    # Is this hostmask in the chanfilter list?
    #
    # @param [String] hostmask the hostmask to check for
    # @return [True, False]
    #
    def is_chanfiltered?(hostmask)
        @list_modes[:chanfilter].include?(hostmask)
    end

    # Is this hostmask in the except list?
    #
    # @param [String] hostmask the hostmask to check for
    # @return [True, False]
    #
    def is_excepted?(hostmask)
        @list_modes[:except].include?(hostmask)
    end

    # Is this hostmask in the invex list?
    #
    # @param [String] hostmask the hostmask to check for
    # @return [True, False]
    #
    def is_invexed?(hostmask)
        @list_modes[:invex].include?(hostmask)
    end
end
