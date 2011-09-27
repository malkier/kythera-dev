# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera.rb: pre-startup routines
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

# Check for latest RubyGems version
unless Gem::VERSION >= '1.8.0'
    puts "kythera: depends on rubygems >= 1.8.0"
    puts "kythera: gem update --system"
    abort
end

# Check for our dependencies before doing _anything_ else
if defined?(JRUBY_VERSION)
    # Run dependencies
    DEPENDENCIES = { 'sequel'   => '~> 3.23' }

    # Special deps we only need on JRuby
    JRUBY_DEPS   = [ 'activerecord-jdbcsqlite3-adapter',
                     'jdbc-sqlite3', 'jruby-openssl' ]
else
    # Run dependencies
    DEPENDENCIES = { 'sequel'   => '~> 3.23',
                     'sqlite3'  => '~> 1.3' }
end

DEPENDENCIES.each do |name, reqs|
    spec = Gem::Specification.find_all_by_name(name, reqs)

    if spec.empty?
        puts "kythera: depends on #{name} #{reqs}"
        puts "kythera: this library is required for operation"
        puts "kythera: gem install --remote #{name}"
        abort
    else
        require name
    end
end

# We need different gems to run on JRuby
if defined?(JRUBY_VERSION)
    JRUBY_DEPS.each do |name|
        spec = Gem::Specification.find_all_by_name(name)

        if spec.empty?
            puts "kythera: depends on #{name}"
            puts "kythera: this library is required for operation on jruby"
            puts "kythera: gem install --remote #{name}"
            abort
        end
    end
end

# Define `irc_downcase` in String
class String
    # Downcase a nick using the config's casemapping
    # RFC 1459 says that `[]\~` is uppercase for `{}|^`, respectively, because
    # of some Scandinavian characters.
    def irc_downcase
        if $uplink.config.casemapping == :rfc1459
            downcase.tr('[]\\~', '{}|^')
        else
            downcase
        end
    end
end

# A Hash that irc_downcases the keys automatically
class IRCHash < Hash
    # Look up a member, but downcase the key first
    #
    # @param [Object] key the value's key
    #
    def [](key)
        super(key.irc_downcase)
    end

    # Set a member, but downcase the key first
    #
    # @param [Object] key the value's key
    # @param [Object] value the value
    #
    def []=(key, value)
        super(key.irc_downcase, value)
    end
end

# Require all the Ruby stdlib stuff we need
require 'logger'
require 'optparse'
require 'ostruct'
require 'singleton'
require 'socket'

require 'digest/sha2'

begin
    require 'openssl'
rescue LoadError
    puts 'kythera: warning: unable to load OpenSSL'
end

# Stub class just to have the constant/namespace around
class Kythera
end

# Require all of our files here and only here
require 'kythera/log'
require 'kythera/channel'
require 'kythera/configure'
require 'kythera/database'
require 'kythera/database/account'
require 'kythera/event'
require 'kythera/extension'
require 'kythera/extension/socket'
require 'kythera/protocol'
require 'kythera/protocol/receive'
require 'kythera/protocol/send'
require 'kythera/run'
require 'kythera/server'
require 'kythera/service'
require 'kythera/timer'
require 'kythera/uplink'
require 'kythera/user'

# Try to load SecureRandom from the stdlib, fall back to vendored version
begin
    require 'securerandom'
rescue LoadError
    require 'kythera/securerandom'
end

# Contains all of the application-wide stuff
class Kythera
    # For backwards-incompatible changes
    V_MAJOR = 0

    # For backwards-compatible changes
    V_MINOR = 1

    # For minor changes and bugfixes
    V_PATCH = 5

    # A String representation of the version number
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    # Our name for things we print out
    ME = 'kythera'
end

#
# Verify that an argument is a valid descendent of a particular class. You can
# optionally provide a name for the argument to make the error message that
# results if the check fails a little bit more clear.
#
# This method will only validate arguments if $config.logging is set to
# :debug, as it's designed to help in writing code. By the time it's
# running in a production environment, the kinks requiring this code
# should be addressed.
#
# @param [Object] var The variable to check
# @param [Class] klass The class of which "var" should be a descendent
# @param [String, #to_s] name The optional name of the variable
# @raise [ArgumentError] If the "var" is not a "klass" object
#
# @example Minimal arguments to verify that "account" is an Account object
#   assert(account, Database::Account)
#
# @example More descriptive, say what variable name we're testing
#   assert(chan, Database::ChannelService::Channel, 'chan')
#
def assert(var, klass, name = nil)
    return if $config.logging == :debug

    unless var.kind_of? klass
        if name
            errstr = "#{name} must be of type #{klass}"
        else
            errstr = "#{var} must be of type #{klass}"
        end

        raise ArgumentError, errstr
    end
end
