# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service.rb: Service class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# A list of all instantiated services
$services = []

# This is the base class for a service. All services modules must subclass this.
# For the full documentation see `doc/extensions.md`
#
class Service
    # A list of all services classes
    @@services_classes = []

    # Attribute reader for `@@services_classes`
    #
    # @return [Array] a list of all services classes
    #
    def self.services_classes
        @@services_classes
    end

    # Detect when we are subclassed
    #
    # @param [Class] klass the class that subclasses us
    #
    def self.inherited(klass)
        @@services_classes << klass
    end

    # Instantiate all of our services
    def self.instantiate
        @@services_classes.each do |srv|
            next unless srv.verify_configuration
            $services << srv.new
        end
    end

    private

    # You must override this or your service doesn't do too much huh?
    def irc_privmsg(user, params)
        $log.debug "I'm a Service that didn't override irc_privmsg!"
    end
end
