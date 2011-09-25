#
# kythera: services for IRC networks
# lib/kythera/protocol/inspircd/user.rb: InspIRCd-specific User class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This subclasses the base User class in `kythera/user.rb`
class Protocol::InspIRCd::User < User
    # InspIRCd usermodes
    @@user_modes = { 'i' => :invisible,
                     'o' => :operator,
                     's' => :receives_snotices,
                     'w' => :wallop,
                     'B' => :bot,
                     'c' => :common_chans,
                     'd' => :chan_deaf,
                     'g' => :callerid,
                     'G' => :censor,
                     'h' => :help_op,
                     'H' => :hide_oper,
                     'I' => :hide_chans,
                     'k' => :serv_protect,
                     'Q' => :unethical,
                     'r' => :registered,
                     'R' => :registered_privmsg,
                     'S' => :strip_color,
                     'W' => :show_whois,
                     'x' => :cloaked }

    # The user's IP address
    attr_reader :ip

    # The user's timestamp
    attr_reader :timestamp

    # The user's UID
    attr_reader :uid

    # Creates a new user and adds it to the list keyed by UID
    def initialize(server, nick, user, host, ip, real, umodes, uid, ts)
        @ip        = ip
        @uid       = uid
        @timestamp = ts.to_i

        super(server, nick, user, host, real, umodes)
    end

    # The value we use to represent our membership in a Hash
    def key
        @uid
    end
end
