# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/inspircd/user.rb: InspIRCd-specific User class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# This subclasses the base User class in `kythera/user.rb`
class Protocol::InspIRCd::User < User
    # InspIRCd usermodes
    @@modes = { 'i' => :invisible,
                'o' => :operator,
                's' => :receives_snotices,
                'w' => :wallop,
                'B' => :bot,
                'c' => :common_channels,
                'd' => :deaf,
                'g' => :caller_id,
                'G' => :censor,
                'h' => :help_op,
                'H' => :hidden_operator,
                'I' => :hidden_channels,
                'k' => :invulnerable,
                'Q' => :unethical,
                'r' => :registered,
                'R' => :registered_privmsg,
                'S' => :strip_color,
                'W' => :show_whois,
                'x' => :hidden_host }

    # The user's IP address
    attr_reader :ip

    # The user's UID
    attr_reader :uid

    # Creates a new user and adds it to the list keyed by UID
    def initialize(server, nick, user, host, ip, real, umodes, ts, uid)
        @ip  = ip
        @uid = uid

        super(server, nick, user, host, real, umodes, ts)
    end

    # The value we use to represent our membership in a Hash
    def key
        @uid
    end
end
