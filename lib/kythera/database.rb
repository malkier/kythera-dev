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
    $db = Sequel.connect('jdbc:sqlite:db/kythera.db') unless $db
else
    $db = Sequel.connect('sqlite:db/kythera.db') unless $db
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

module Sequel
    class Model
        STRIP_UNSAFE_VAR_NAMES = /[^a-z_]/i

        #########
        protected
        #########

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
        # This method will only validate arguments if $config.logging is set to
        # :debug, as it's designed to help in writing code. By the time it's
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
        def self.assert(&block)
            return unless $config.logging == :debug

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
                camelize(str.to_s.gsub(STRIP_UNSAFE_VAR_NAMES, ''))
            end

            # turn SomeClass into some_class.
            to_var = lambda do |cls|
                underscore(cls.to_s.gsub(STRIP_UNSAFE_VAR_NAMES, ''))
            end

            # if they just passed :some_arg or SomeClass, camelize or
            # de-camelize as necessary.
            if args.is_a? Symbol or args.is_a? Class
                to_check[ to_var.call(args) ] = to_class.call(args)

            # if they passed an array of :some_arg or SomeClass, camelize or
            # de-camelize each arg, as necessary.
            elsif args.is_a? Array
                args.each do |arg|
                    to_check[ to_var.call(arg) ] = to_class.call(arg)
                end

            # they were pretty explicit here, :some_arg => SomeClass. we still
            # wipe their args clean but we know there's probably something named
            # differently here.
            elsif args.is_a? Hash
                args.each do |varname, classname|
                    to_check[ to_var.call(varname) ] = to_class.call(classname)
                end
            end

            # check each variable in its original scope.
            to_check.each do |var, klass|
                unless bind.eval("#{var}.kind_of?(#{klass})")
                    errors << "argument #{var} must be of type #{klass}"
                end
            end

            # all arguments passed muster, yay!
            return if errors.empty?

            # this is just me being an English pedant.
            if errors.length == 1
                errstr = errors[0]
            else
                errstr = ary[0 ... -1].join(', ')
                errstr = [str, ary[-1]].join(' and ')
                errstr = str[0].upcase + str[1 .. -1] + '.'
            end

            # raise an ArgumentError in the calling scope, so we're a ghost in
            # the process and don't send people scurrying to this file to find
            # a problem that's probably somewhere else.
            raise ArgumentError, errstr, caller
        end

        #
        # Instance-level wrapper for Sequel::Model.assert, see the documentation
        # for that method.
        #
        # @private
        # @param [Proc] block Block returning argument types
        # @raise [ArgumentError] if arguments don't match type
        #
        def assert(&block); self.class.assert(&block) end
    end
end
