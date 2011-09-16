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

# Require all of our files here and only here
require 'kythera/log'
require 'kythera/channel'
require 'kythera/configure'
require 'kythera/database'
require 'kythera/event'
require 'kythera/extension'
require 'kythera/extension/socket'
require 'kythera/protocol'
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
