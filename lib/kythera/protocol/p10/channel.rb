# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/p10/channel.rb: P10-specific Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# This subclasses the base Channel class in `kythera/channel.rb`
class Protocol::P10::Channel < Channel
    # Standard IRC cmodes requiring a param
    @@param_modes  = { 'A' => :admin_key,
                       'D' => :hidden_joins,
                       'k' => :keyed,
                       'l' => :limited,
                       'R' => :registered,
                       'r' => :registered_only,
                       'U' => :user_key }
end
