#
# kythera: services for IRC networks
# lib/kythera.rb: configuration DSL implementation
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

# Check for our dependencies before doing _anything_ else
begin
    lib = nil
    %w(rubygems sequel sqlite3).each do |m|
        lib = m
        require lib
    end
rescue LoadError
    puts "kythera: could not load #{lib}"
    puts "kythera: this library is required for operation"
    puts "kythera: gem install --remote #{lib}"
    abort
end

# Require all the Ruby stdlib stuff we need
require 'logger'
require 'optparse'
require 'ostruct'
require 'singleton'
require 'socket'

# Require all of our files here and only here
require 'kythera/loggable'
require 'kythera/channel'
require 'kythera/event'
require 'kythera/protocol'
require 'kythera/run'
require 'kythera/server'
require 'kythera/service'
require 'kythera/timer'
require 'kythera/uplink'
require 'kythera/user'

# Require all of our services and extensions
Dir.glob(['lib/kythera/service/*.rb', 'ext/*rb']) do |filepath|
    require filepath.split(File::SEPARATOR, 2)[-1]
end

# Starts the parsing of the configuraiton DSL
#
# @param [Proc] block contains the actual configuration code
#
def configure(&block)
    $config = Object.new

    class << $config
        # Adds methods to the parser from an arbitrary module
        #
        # @param [Module] mod the module containing methods to add
        #
        def use(mod)
            $config.extend(mod)
        end
    end

    # The configuration magic begins here...
    $config.instance_eval(&block)

    # Make sure the configuration information is valid
    Kythera.verify_configuration

    # Configuration is solid, now let's actually start up
    Kythera.new
end

# Contains all of the application-wide stuff
class Kythera
    # For backwards-incompatible changes
    V_MAJOR = 0

    # For backwards-compatible changes
    V_MINOR = 0

    # For minor changes and bugfixes
    V_PATCH = 1

    # A String representation of the version number
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    # Our name for things we print out
    ME = 'kythera'

    # Verifies that the configuration isn't invalid or incomplete
    def self.verify_configuration
        # XXX - configuration verification
        $config.uplinks.sort! { |a, b| a.priority <=> b.priority }
    end
end

# Contains the methods that actually implement the configuration
module Kythera::Configuration
    # Holds the settings for the daemon section
    attr_reader :me

    # Holds the settings for the uplink section
    attr_reader :uplinks

    # Parses the `daemon` section of the configuration
    #
    # @param [Proc] block contains the actual configuration code
    #
    def daemon(&block)
        return if @me

        @me = OpenStruct.new
        @me.extend Kythera::Configuration::Daemon
        @me.instance_eval(&block)
    end

    # Parses the `uplink` section of the configuration
    #
    # @param [String] name the server name
    # @param [Proc] block contains the actual configuraiton code
    #
    def uplink(host, port = 6667, &block)
        ul      = OpenStruct.new
        ul.host = host
        ul.port = port

        ul.extend Kythera::Configuration::Uplink
        ul.instance_eval(&block)

        (@uplinks ||= []) << ul
    end
end

# Implements the daemon section of the configuration
#
# If you're writing an extension that needs to add settings here,
# you should provide your own via `use`.
#
# @example Extend the daemon settings
#     daemon do
#         use MyExtension::Configuration::Daemon
#
#         # ...
#     end
#
# Directly reopening this module is possible, but not advisable.
#
module Kythera::Configuration::Daemon
    # Adds methods to the parser from an arbitrary module
    #
    # @param [Module] mod the module containing methods to add
    #
    def use(mod)
        self.extend(mod)
    end

    private

    def name(name)
        self.name = name
    end

    def description(desc)
        self.description = desc
    end

    def admin(name, email)
        self.admin_name  = name
        self.admin_email = email
    end

    def logging(level)
        self.logging = level
    end

    def reconnect_time(time)
        self.reconnect_time = time
    end

    def verify_emails(bool)
        self.verify_emails = bool
    end

    def mailer(mailer)
        self.mailer = mailer
    end
end

# Implements the uplink section of the configuration
#
# If you're writing an extension that needs to add settings here,
# you should provide your own via `use`.
#
# @example Extend the uplink settings
#     uplink 'some.up.link' do
#         use MyExtension::Configuration::Uplink
#
#         # ...
#     end
#
# Directly reopening this module is possible, but not advisable.
# Although there can be multiple `uplink` blocks in the configuration,
# you should only need to use `use` once.
#
module Kythera::Configuration::Uplink
    # Adds methods to the parser from an arbitrary module
    #
    # @param [Module] mod the module containing methods to add
    #
    def use(mod)
        self.extend(mod)
    end

    private

    def priority(pri)
        self.priority = pri.to_i
    end

    def name(name)
        self.name = name
    end

    def bind(host, port = nil)
        self.bind_host = host
        self.bind_port = port
    end

    def send_password(password)
        self.send_password = password
    end

    def receive_password(password)
        self.receive_password = password
    end

    def network(name)
        self.network = name
    end

    def protocol(protocol)
        self.protocol = protocol

        # Check to see if they specified a valid protocol
        begin
            require "kythera/protocol/#{protocol.to_s.downcase}"
        rescue LoadError
            raise "invalid protocol `#{protocol}` for uplink `#{name}`"
        end

        proto = Protocol.find(protocol)

        raise "invalid protocol `#{protocol}` for uplink `#{name}`" unless proto
    end

    def sid(sid)
        self.sid = sid
    end

    def casemapping(mapping)
        self.casemapping = mapping
    end
end
