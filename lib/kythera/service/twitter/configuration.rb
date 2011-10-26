# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/twitter/configuration.rb: implements configuration DSL
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# Contains the methods that do the config parsing
module TwitterService::Configuration
    # Adds methods to the parser from an arbitrary module
    #
    # @param [Module] mod the module containing methods to add
    #
    def use(mod)
        self.extend(mod)
    end

    private

    def nickname(nick)
        self.nickname = nick.to_s
    end

    def username(user)
        self.username = user.to_s
    end

    def hostname(host)
        self.hostname = host.to_s
    end

    def realname(real)
        self.realname = real.to_s
    end

    def channel(channel)
        self.channel = channel
    end
end
