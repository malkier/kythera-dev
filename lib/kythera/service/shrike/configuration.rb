# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/shrike/configuration.rb: implements configuration DSL
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# Contains the methods that do the config parsing
module ShrikeService::Configuration
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

    def channel(chan)
        self.channel = chan
    end

    def sras(*args)
        self.sras ||= []

        args.each { |sra| self.sras << sra.to_s }
    end
end
