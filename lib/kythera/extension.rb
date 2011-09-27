# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/extension.rb: extensions interface
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# A list of all extension classes
$extensions = []

# This is the base class for an extension. All extensions must subclass this.
# For the full documentation see `doc/extensions.md`
#
class Extension
    # Detect when we are subclassed
    #
    # @param [Class] klass the class that subclasses us
    #
    def self.inherited(klass)
        $extensions << klass
    end

    # Verify loaded extensions work with our version
    def self.verify_and_load
        # Remove the incompatible ones
        $extensions.delete_if do |klass|
            kyver = Gem::Requirement.new(klass::KYTHERA_VERSION)

            unless kyver.satisfied_by?(Gem::Version.new(Kythera::VERSION))
                if $config.me.unsafe_extensions == :ignore
                    false # Load anyway
                    next
                else
                    puts "kythera: incompatable extension '#{klass::NAME}'"
                    puts "kythera: needs kythera version '#{kyver}'"
                end

                abort if $config.me.unsafe_extensions == :die

                true # Don't load
            end
        end

        # Check to see if the dependencies are satisfied
        $extensions.each do |klass|
            kn = klass::NAME

            klass::DEPENDENCIES.each do |n, reqs|
                spec = Gem::Specification.find_all_by_name(n, reqs)

                if spec.empty?
                    puts "kythera: extension '#{kn}' requires #{n} #{reqs}"
                    puts "kythera: gem install --remote #{n}"
                    abort
                end
            end
        end

        # Load the ones that passed verification
        $extensions.each do |klass|
            # Does this extension have a configuration block?
            if $state.ext_cfg and $state.ext_cfg[klass::NAME.to_sym]
                cfg = $state.ext_cfg[klass::NAME.to_sym]

                return unless klass.verify_configuration(cfg)

                k = klass.initialize(cfg)
            else
                klass.initialize
            end
        end

        # Clear the extension configuration blocks
        $state.ext_cfg = nil
    end
end
