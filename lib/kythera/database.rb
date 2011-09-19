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

#
# A namespace to encapsulate all database-related modules and classes. The API
# specified here should be transaction-safe and immediately write changes made.
# This makes the service stay in sync with the database, and any crashes should
# not cause data loss.
#
module Database
    #
    # Returns the loaded version of the schema. This is useful for extensions
    # that are loading models into the database, or just for the curious.
    #
    # @return [String] A 3-digit number of the schema version
    #
    def self.version
        @@version ||= $db['SELECT * FROM schema_info'].first[:version]
        '%03d' % @@version
    end
end
