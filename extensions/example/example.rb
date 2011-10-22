# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# extensions/example/example.rb: example extension
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

class ExampleExtension
    include Singleton

    @@config = nil

    def self.config=(config)
        @@config = config
    end

    # If you get here, you're loaded and ready to go
    def initialize
        puts "ExampleExtension has been initialized!"
    end
end
