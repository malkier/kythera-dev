# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/shrike/commands.rb: implements shrike's X
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

class ShrikeService < Service
    private

    # This command makes the entire application shut down.
    def do_shutdown(user, params)
        return unless is_sra?(user.nickname) # XXX account, not nickname

        reason = params.join(' ')

        wallop(@user.key, "shutdown requested by #{user}: #{reason}")

        $eventq.post(:exit, "#{user}: #{reason}")
    end

    # This is dangerous, and is only here for my testing purposes!
    def do_raw(user, params)
        return unless is_sra?(user.nickname) # XXX account, not nickname

        raw(params.join(' '))
    end

    # Extremely dangerous, this is here only for my testing purposes!
    def do_eval(user, params)
        return unless is_sra?(user.nickname) # XXX account, not nickname

        code = params.join(' ')

        result = eval(code)

        privmsg(@user.key, @config.channel, "#{result.inspect}")
    end

    # Registers a username or channel
    def do_register(user, params)
    end
end
