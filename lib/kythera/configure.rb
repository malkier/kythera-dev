# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/configure.rb: configuration DSL implementation
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# An exception used to control configuration errors
class ConfigurationError < Exception
end

# Starts the parsing of the configuraiton DSL
#
# @param [Proc] block contains the actual configuration code
#
def configure(&block)
    # If we're already running, this is a rehash
    return rehash(&block) if $state and $state.rehashing

    # This is for storing random application states
    $state  = OpenStruct.new
    $config = Object.new
    $eventq = EventQueue.new

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

    # Verify extension compatibility
    Extension.verify_and_load

    # Configuration is solid, now let's actually start up
    Kythera.new
end

# Same as above, but used for unit tests, and so doesn't run the app
def configure_test(&block)
    unless $config
        $state  = OpenStruct.new
        $config = Object.new
        $eventq = EventQueue.new

        $config.extend(Kythera::Configuration)
    end

    $config.instance_eval(&block)
end

# Reload the configuration file
def rehash(&block)
    return unless $state.rehashing

    $log.info "reloading configuration file"

    # Are we being run with -d? We should keep it if so
    logging = $config.me.logging

    # Clear uplinks
    uplinks = $config.uplinks.dup
    $config.uplinks.clear

    # Do the rehash
    begin
        $config.instance_eval(&block)
    rescue ConfigurationError => err
        $log.error "error reloading configuration: #{err}"

        $config.uplinks  = uplinks
        $state.rehashing = false
    end

    # Restore debug mode if it was on
    if logging == :debug
        $config.me.logging = :debug
        Log.log_level = :debug
    end

    # Update the services' configuration data
    $services.each do |service|
        service.config = $state.srv_cfg[service.class::NAME.to_sym]
    end

    # Load any new extensions and update their configuration data
    Extension.verify_and_load

    # Done rehashing
    $state.rehashing = false

    # Let everyone know a rehash occured
    $eventq.post(:rehash)
end

# Contains the methods that actually implement the configuration
module Kythera::Configuration
    # Holds the settings for the daemon section
    attr_reader :me

    # Holds the settings for the uplink section
    attr_reader :uplinks

    # Reports an error about an unknown directive
    def method_missing(meth, *args, &block)
       puts "kythera: unknown configuration directive '#{meth}' (ignored)"
    end

    # Prevent configuration from calling `Kythera.new`
    def dry_run
        self.dry_run = true
    end

    # Load a service and parse its configuration
    #
    # The configuration will be placed at $config.name_of_service
    #
    # @param [Symbol] name name of the service
    #
    def service(name, &block)
        # Load it if it's not loaded
        unless Service.services_classes.find { |s| s::NAME == name }
            begin
                require "kythera/service/#{name}"
            rescue LoadError
                puts "kythera: couldn't load service: #{name} (ignored)"
                return
            end
        end

        # That's all we need to do unless there's config to parse
        return unless block_given?

        # Find the Service's class
        srv = Service.services_classes.find { |s| s::NAME == name }

        $state.srv_cfg ||= {}

        begin
            # Find the Service's configuration methods
            srv_config_parser = srv::Configuration
        rescue NameError
            if block_given?
                puts "kythera: service has no configuration handlers: #{name}"
            end
        else
            # Parse the configuration block
            srv_config = OpenStruct.new
            srv_config.extend(srv_config_parser)
            srv_config.instance_eval(&block)

            # Store it in $state.ext_cfg
            $state.srv_cfg[srv::NAME] = srv_config
        end
    end

    # Load an extension's configuration
    #
    # If an extension provides configuration methods, this method parses the
    # configuration into an OpenStruct like the rest of the configuration and
    # stores it in `$state`. When the extension is verified & loaded, the
    # OpenStruct will be passed to its initialize method. If it fails
    # verification it will be erased.
    #
    # @param [Symbol] name the name of the extension
    #
    def extension(name, &block)
        # Start by loading the extension header
        begin
            require "extensions/#{name}/header"
        rescue LoadError
            puts "kythera: couldn't load extension header: #{name} (ignored)"
            return
        end

        # That's all we need to do unless there's config to parse
        return unless block_given?

        # Find the Extension's class
        ext = $extensions.find { |e| e::NAME == name }

        $state.ext_cfg ||= {}

        begin
            # Find the Extensions's configuration methods
            ext_config_parser = ext::Configuration
        rescue NameError
            if block_given?
                puts "kythera: extension has no configuration handlers: #{name}"
            end
        else
            # Parse the configuration block
            ext_config = OpenStruct.new
            ext_config.extend(ext_config_parser)
            ext_config.instance_eval(&block)

            # Store it in $state.ext_cfg
            $state.ext_cfg[ext::NAME] = ext_config
        end
    end

    # Parses the `daemon` section of the configuration
    #
    # @param [Proc] block contains the actual configuration code
    #
    def daemon(&block)
        @me = OpenStruct.new
        @me.extend(Kythera::Configuration::Daemon)
        @me.instance_eval(&block)
    end

    # Parses the `uplink` section of the configuration
    #
    # @param [String] name the server name
    # @param [Proc] block contains the actual configuraiton code
    #
    def uplink(host, port = 6667, &block)
        ul      = OpenStruct.new
        ul.host = host.to_s
        ul.port = port.to_i

        ul.extend(Kythera::Configuration::Uplink)
        ul.instance_eval(&block)

        ul.name ||= host.to_s

        (@uplinks ||= []) << ul

        $config.uplinks.sort! { |a, b| a.priority <=> b.priority }
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
    # Reports an error about an unknown directive
    def method_missing(meth, *args, &block)
        begin
            super
        rescue NoMethodError
            puts "kythera: unknown config directive 'daemon:#{meth}' (ignored)"
        end
    end

    # Adds methods to the parser from an arbitrary module
    #
    # @param [Module] mod the module containing methods to add
    #
    def use(mod)
        self.extend(mod)
    end

    private

    def name(name)
        self.name = name.to_s
    end

    def description(desc)
        self.description = desc.to_s
    end

    def admin(name, email)
        self.admin_name  = name.to_s
        self.admin_email = email.to_s
    end

    def logging(level)
        self.logging = level

        # Kythera.new will set this up fully later
        Log.logger    = Logger.new($stdout)
        Log.log_level = level
    end

    def unsafe_extensions(action)
        self.unsafe_extensions = action
    end

    def reconnect_time(time)
        self.reconnect_time = time.to_i
    end

    def verify_emails(bool)
        self.verify_emails = bool
    end

    def mailer(mailer)
        self.mailer = mailer.to_s
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
    # Reports an error about an unknown directive
    def method_missing(meth, *args, &block)
        begin
            super
        rescue NoMethodError
            puts "kythera: unknown config directive 'uplink:#{meth}' (ignored)"
        end
    end

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
        self.name = name.to_s
    end

    def bind(host, port = nil)
        self.bind_host = host.to_s
        self.bind_port = port.to_i
    end

    def ssl
        if defined?(OpenSSL)
            self.ssl = true
        else
            $log.warn "OpenSSL is not available; SSL disabled for #{self.host}"
        end
    end

    def sid(sid)
        self.sid = sid.to_s
    end

    def send_password(password)
        self.send_password = password.to_s
    end

    def receive_password(password)
        self.receive_password = password.to_s
    end

    def network(name)
        self.network = name.to_s
    end

    def protocol(protocol)
        self.protocol = protocol.to_sym

        # Check to see if they specified a valid protocol
        begin
            require "kythera/protocol/#{protocol.to_s.downcase}"
        rescue LoadError
            raise "invalid protocol `#{protocol}` for uplink `#{name}`"
        end

        proto = Protocol.find(protocol)

        raise "invalid protocol `#{protocol}` for uplink `#{name}`" unless proto
    end

    def casemapping(mapping)
        self.casemapping_override = true
        self.casemapping = mapping.to_sym
    end
end
