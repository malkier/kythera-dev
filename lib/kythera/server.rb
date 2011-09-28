# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/server.rb: Server class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# A list of all servers; keyed by server name by default
$servers = IRCHash.new

# This is just a base class; protocol module should subclass this
class Server
    # The server's name
    attr_reader :name

    # The server's description
    attr_reader :description

    # The Users on this server
    attr_reader :users

    # Creates a new server. Should be patched by the protocol module.
    def initialize(name, description)
        assert { { :name => String, :description => String } }

        @name        = name
        @description = description
        @users       = []

        $servers[key] = self

        $eventq.post(:server_added, self)

        $log.debug "new server initialized: #{@name} [#{@description}]"
    end

    public

    # String reprensentation
    def to_s
        @name
    end

    # The value we use to represent our membership in a Hash
    def key
        @name
    end

    # Adds a User as a member
    #
    # @param [User] user the User to add
    #
    def add_user(user)
        assert { :user }

        @users << user
        $log.debug "user joined #{@name}: #{user}"
    end

    # Deletes a User as a member
    #
    # @param [User] user User object to delete
    #
    def delete_user(user)
        assert { :user }

        @users.delete(user)
        $log.debug "user left #{@name}: #{user} (#{@users.length})"
    end
end
