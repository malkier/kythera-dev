# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# extensions/example/header.rb: example extension header
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

class ExampleExtensionHeader < Extension
    NAME = :example

    KYTHERA_VERSION = '~> 0.0'
    DEPENDENCIES    = { 'sequel'   => '~> 3.23' }

    # This is called if your versions are right and your dependencies are met.
    # The rest is up to you.
    #
    def self.initialize(config = nil)
        require 'extensions/example/example'
        ExampleExtension.new(config)
    end

    # Our configuration methods
    module Configuration
        private

        def example_setting(rvalue)
            self.example_setting = rvalue
        end
    end
end
