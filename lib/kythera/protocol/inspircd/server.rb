# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/inspircd/server.rb: InspIRCd-specific Server class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This subclasses the base Server class in `kythera/server.rb`
class Protocol::InspIRCd::Server < Server
    # The server's SID
    attr_reader :sid

    # Creates a new Server and adds it to the list keyed by SID
    def initialize(sid, name, description)
        @sid = sid
        super(name, description)
    end

    # The value we use to represent our membership in a Hash
    def key
        @sid
    end
end
