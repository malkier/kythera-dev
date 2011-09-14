#
# kythera: services for IRC networks
# extensions/diakofti/header.rb: diakofti header
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

class DiakoftiHeader < Extension
    NAME = :diakofti

    KYTHERA_VERSION = '~> 0.0'
    DEPENDENCIES    = {}

    # This is called if your versions are right and your dependencies are met.
    # The rest is up to you.
    #
    def self.initialize(config = nil)
        require 'extensions/diakofti/diakofti'
        Diakofti.new(config)
    end

    # Verify our configuration
    #
    # @return [Boolean] true or false
    #
    def self.verify_configuration(c)
        if not c or not c.port then false else true end        #
                #     false
                # else
                #     true
                # end
    end

    # Our configuration methods
    module Configuration
        # Reports an error about an unknown directive
        def method_missing(meth, *args, &block)
            begin
                super
            rescue NoMethodError
                str  = 'kythera: unknown configuration directive '
                str += "'diakofti:#{meth}' (ignored)"

                puts str
            end
        end

        private

        def port(rvalue)
            self.port = rvalue
        end

        def bind(rvalue)
            self.bind = rvalue
        end
    end
end
