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

    # Delete a member, but downcase the key first
    #
    # @param [Object] key the key to be deleted
    #
    def delete(key)
        super(key.irc_downcase)
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
    V_PATCH = 7

    # A String representation of the version number
    VERSION = "#{V_MAJOR}.#{V_MINOR}.#{V_PATCH}"

    # Our name for things we print out
    ME = 'kythera'
end

# Used to filter the input to the assert method
STRIP_UNSAFE_VAR_NAMES = /[^a-z_]/i

#
# Asserts that arguments match a certain class, and raises errors if
# they do not. The arguments are passed as return values from a block
# which makes certain assumptions for how the variables would be named
# in the scope of the method. For instance, an "account" variable should
# be an Account object.
#
# The simplest way to use the method is to pass a block which returns a
# single Symbol (containing the variable name) or Class (the class of
# which the variable should be a type). The earlier stated assumptions
# hold in this case. You can also pass an array (which can mix Symbol
# and Class elements) which makes the same assumptions about each
# individual element.
#
# The more explicit mechanism of declaring variables using a hash should
# be reserved for when variables aren't named according to their type.
# The hash should be formatted with keys being the variable names, and
# values being the classes.
#
# Only the "returning a single Symbol" method of checking types requires
# that the argument be a Symbol, all other methods can take a String,
# Class, Symbol, or whatever other representation can be converted to
# a string that describes the name and/or type.
#
# This method will only validate arguments if $config.me.logging is set
# to :debug, as it's designed to help in writing code. By the time it's
# running in a production environment, the kinks requiring this code
# should be addressed.
#
# @private
# @param [Proc] block Block returning argument types
# @raise [ArgumentError] If arguments don't match type
#
# @example Using a single Symbol class to define an argument
#   def drop(account)
#       assert { :account } # verify account is an Account object
#       account.delete # perform an Account-specific action
#   end
#
# @example Verifying multiple arguments in an Array
#   def get_privileges(account, channel)
#       assert { [:account, Channel] } # mixed type is allowed
#       Privilege[:account => account, :channel => channel].all
#   end
#
# @example Validating arguments that don't use the naming convention
#   def message(from, to, message)
#       # strings are allowed as keys or values
#       assert { {'from' => Account, :to => 'Account'} }
#       Message.new(from, to, message).send!
#   end
#
def assert(&block)
    return unless $config.me.logging == :debug

    # get the arguments and the scope in which they were declared.
    args = block.call
    bind = block.binding

    # predeclare to_check, which contains our list of variables to
    # validate, and errors, which contains the list of ones that don't
    # meet their respective criterion.
    to_check = {}
    errors   = []

    # turn :some_arg into SomeArg.
    to_class = lambda do |str|
        Sequel::Model.send(:camelize, str.to_s.gsub(STRIP_UNSAFE_VAR_NAMES, ''))
    end

    # turn SomeClass into some_class.
    to_var = lambda do |cls|
        cls = cls.to_s.split('::')[-1]
        Sequel::Model.send(:underscore, cls.gsub(STRIP_UNSAFE_VAR_NAMES, ''))
    end

    # if they just passed :some_arg or SomeClass, camelize or
    # de-camelize as necessary.
    if args.is_a?(String) or args.is_a?(Symbol) or args.is_a?(Class)
        to_check[ to_var.call(args) ] = to_class.call(args)

    # if they passed an array of :some_arg or SomeClass, camelize or
    # de-camelize each arg, as necessary.
    elsif args.is_a?(Array)
        args.each do |arg|
            to_check[ to_var.call(arg) ] = to_class.call(arg)
        end

    # they were pretty explicit here, :some_arg => SomeClass. we still
    # wipe their args clean but we know there's probably something named
    # differently here.
    elsif args.is_a?(Hash)
        args.each do |varname, classname|
            to_check[ to_var.call(varname) ] = to_class.call(classname)
        end
    end

    # check each variable in its original scope.
    to_check.sort { |a, b| a[0] <=> b[0] }.each do |var, klass|
        unless bind.eval("#{var}.kind_of?(#{klass})")
            full = bind.eval("#{klass}.to_s")
            real = bind.eval("#{var}.class")
            errors << %Q{argument "#{var}" must be of type "#{klass}"} +
                      %Q{ but was of type "#{real}"}
        end
    end

    # all arguments passed muster, yay!
    return if errors.empty?

    # this is just me being an English pedant.
    if errors.length == 1
        errstr = errors[0]
    else
        errstr = errors[0 ... -1].join(', ')
        errstr = [errstr, errors[-1]].join(' and ')
        errstr = errstr[0].upcase + errstr[1 .. -1] + '.'
    end

    # raise an ArgumentError in the calling scope, so we're a ghost in
    # the process and don't send people scurrying to this file to find
    # a problem that's probably somewhere else.
    raise ArgumentError, errstr, caller
end
