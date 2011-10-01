# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/p10.rb: implements the P10 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Protocol::P10
end

require 'kythera/protocol/p10/token'
require 'kythera/protocol/p10/receive'
require 'kythera/protocol/p10/send'
require 'kythera/protocol/p10/server'
require 'kythera/protocol/p10/user'

# Implements P10 protocol-specific methods
module Protocol::P10
    include Protocol

    # The current UID for Services
    @@current_uid = 0

    public

    # Introduces a pseudo-client to the network
    #
    # @param [String] nick user's nickname
    # @param [String] user user's username
    # @param [String] host user's hostname
    # @param [String] real user's realname / gecos
    #
    def introduce_user(nick, user, host, real, modes = '')
        assert { { :nick  => String,
                   :user  => String,
                   :host  => String,
                   :real  => String,
                   :modes => String } }

        send_nick(nick, user, host, real, modes)
    end

    # Makes one of our clients join a channel
    #
    # @param [String] origin the entity joining the channel
    # @param [String] target the channel to join
    #
    def join(origin, target)
        assert { { :origin => String, :target => String } }

        raw "#{origin} J #{target}"
    end
end
