# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6/user.rb: TS6-specific User class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# This sublcasses the base User class in `kythera/user.rb`
class Protocol::TS6::User < User
    # ircd-ratbox user modes
    @@modes = { 'a' => :administrator,
                'i' => :invisible,
                'o' => :operator,
                'w' => :wallop,
                'D' => :deaf }

    # The user's IP address
    attr_reader :ip

    # The user's UID
    attr_reader :uid

    # Creates a new user and adds it to the list keyed by UID
    def initialize(server, nick, user, host, ip, real, umodes, ts, uid)
        assert { { :ip => String, :uid => String } }

        @ip  = ip
        @uid = uid

        super(server, nick, user, host, real, umodes, ts)
    end

    # The value we use to represent our membership in a Hash
    def key
        @uid
    end
end
