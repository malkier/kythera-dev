# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/chanserv.rb: implements the channel service
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'
require 'kythera/service/chanserv/database'

# Provides services for operator commands
class ChannelService < Service
    # Our name (for use in the config, etc)
    NAME = :chanserv

    # Backwards-incompatible changes
    V_MAJOR = 0

    # Backwards-compatible changes
    V_MINOR = 0

    # Minor changes and bugfixes
    V_PATCH = 0

    # String representation of our version..
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    PRIVILEGES         = [:recover, :drop, :mlock]
    CHANNEL_PRIVILEGES = [:founder, :successor, :autoop, :autovoice]
end
