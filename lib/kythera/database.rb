#
# kythera: services for IRC networks
# lib/kythera/database.rb: database routines
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# JRuby needs special database adapters
if defined?(JRUBY_VERSION)
    $db = Sequel.connect('jdbc:sqlite:db/kythera.db')
else
    $db = Sequel.connect('sqlite:db/kythera.db')
end

# Namespace to bind objects to the database
module Database
    # Returns the loaded version of the schema. This is useful for extensions
    # that are loading models into the database, or just for the curious.
    def self.version
        @@version ||= $db['SELECT * FROM schema_info'].first[:version]
        '%03d' % @@version
    end

    # DRY - this code was duplicated in all *Flag objects
    module GenericFlag
        # Converts to a String
        def to_s
            flag
        end

        # Converts to a Symbol
        def to_sym
            flag.to_sym
        end
    end
end

require 'kythera/database/account'
