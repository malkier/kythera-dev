# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/p10/user.rb: P10-specific User class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This sublcasses the base User class in `kythera/user.rb`
class Protocol::P10::User < User
    # Ratbox user modes
    @@user_modes = { 'a' => :administrator,
                     'i' => :invisible,
                     'o' => :operator,
                     'r' => :registered,
                     'w' => :wallop }

    # The user's IP address
    attr_reader :ip

    # The user's timestamp
    attr_accessor :timestamp

    # The user's UID
    attr_reader :uid

    # Creates a new user and adds it to the list keyed by UID
    def initialize(server, nick, user, host, ip, real, umodes, uid, ts)
        assert { { :ip => String, :uid => String } }

        @ip        = Protocol::P10.base64_decode(ip)
        @ip        = IPAddr.new(@ip, Socket::AF_INET).to_s
        @uid       = uid
        @timestamp = ts.to_i

        super(server, nick, user, host, real, umodes)
    end

    # The value we use to represent our membership in a Hash
    def key
        @uid
    end
end
