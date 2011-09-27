# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/shrike/commands.rb: implements shrike's X
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

class ShrikeService < Service
    private

    # This is dangerous, and is only here for my testing purposes!
    def do_raw(user, params)
        return unless is_sra?(user.nickname)

        @uplink.raw(params.join(' '))
    end

    # Extremely dangerous, this is here only for my testing purposes!
    def do_eval(user, params)
        return unless is_sra?(user.nickname)

        code = params.join(' ')

        result = eval(code)

        @uplink.privmsg(@user.uid, @config.channel, "#{result.inspect}")
    end

    # Registers a username or channel
    def do_register(user, params)
    end
end
