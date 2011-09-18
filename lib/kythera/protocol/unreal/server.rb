#
# kythera: services for IRC networks
# lib/kythera/protocol/unreal/server.rb: UnrealIRCd-specific Server class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This subclasses the base Server class in `kythera/server.rb`
class Protocol::Unreal::Server < Server
    # Creates a new Server and adds it to the list keyed by name
    def initialize(name)
        @name   = name
        @users  = []

        if $servers[name]
            $log.error "new server replacing server with same name!"
        end

        $servers[name] = self

        $log.debug "new server initialized: #{@name}"
    end
end
