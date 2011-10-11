# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# extensions/diakofti/header.rb: diakofti header
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
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
    # @return [True, False]
    #
    def self.verify_configuration(c)
        return false if not c or not c.port

        if c.ssl_certificate and c.ssl_private_key
           ctx = OpenSSL::SSL::SSLContext.new
           ctx.cert = c.ssl_certificate
           ctx.key  = c.ssl_private_key

           ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
           ctx.options     = OpenSSL::SSL::OP_NO_TICKET
           ctx.options    |= OpenSSL::SSL::OP_NO_SSLv2
           ctx.options    |= OpenSSL::SSL::OP_ALL

           c.ssl_context = ctx
        end

        true
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

        def ssl_certificate(certfile)
            fr = File.read(certfile.to_s)
            self.ssl_certificate = OpenSSL::X509::Certificate.new(fr)
        end

        def ssl_private_key(keyfile)
            fr = File.read(keyfile.to_s)
            self.ssl_private_key = OpenSSL::PKey::RSA.new(fr)
        end
    end
end
