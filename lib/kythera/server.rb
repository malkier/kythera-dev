#
# kythera: services for IRC networks
# lib/kythera/server.rb: Server class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# A list of all servers. The protocol module should decide what the key is.
$servers = IRCHash.new

# This is just a base class. All protocol module should monkeypatch this.
class Server
    # The server's name
    attr_accessor :name

    # The server's description
    attr_accessor :description

    # The Users on this server
    attr_reader :users

    # Creates a new server. Should be patched by the protocol module.
    def initialize(name)
        @name   = name
        @users  = []

        if $servers[name]
            $log.error "new server replacing server with same name!"
        end

        $servers[name] = self

        $log.debug "new server initialized: #{@name}"
    end

    public

    # Adds a User as a member
    #
    # @param [User] user the User to add
    #
    def add_user(user)
        @users << user
        $log.debug "user joined #{@name}: #{user}"
    end

    # Deletes a User as a member
    #
    # @param [User] user User object to delete
    #
    def delete_user(user)
        @users.delete(user)
        $log.debug "user left #{@name}: #{user} (#{@users.length})"
    end
end
