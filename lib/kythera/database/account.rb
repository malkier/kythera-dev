#
# kythera: services for IRC networks
# lib/kythera/database/account.rb: core account and accountfield models
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This is the core Account model which all services and extensions should use
# for user management. While you can push directly into the database using
# built-in Sequel ORM magic, it's advised you treat the class as read-only
# except for the API specified here.
#

module Database
    class Account < Sequel::Model
        one_to_many :account_fields

        @@resolvers = []
        @@droppers  = []
        @@users     = {}

        def intialize(*args)
            super

            @@users[id] ||= []
            @helpers = {}
        end

        def self.register_resolver(&block)
            @@resolvers << block
        end

        def self.before_drop(&block)
            @@droppers << block
        end

        def self.helper(aliases, klass)
            aliases = *aliases
            prime_alias = aliases.shift.to_sym

            define_method(prime_alias) do
                @helpers[prime_alias] ||= klass.new(self)
            end
            aliases.each { |a| define_method(a.to_sym) { prime_alias } }
        end

        def self.resolve(acct_to_resolve)
            begin
                resolve!(acct_to_resolve)
            rescue ResolveError
                nil
            end
        end

        def self.resolve!(acct_to_resolve)
            return self if acct_to_resolve.kind_of?(self)

            if acct_to_resolve.kind_of?(Integer)
                account = Account[acct_to_resolve] rescue nil
                return account if account
            end

            account = Account[:login => acct_to_resolve.to_s].first rescue nil
            return acct if acct

            @@resolvers.each do |resolver|
                account = resolver.call(acct_to_resolve) rescue nil
                return account if account
            end

            raise ResolveError, acct_to_resolve
        end

        def self.drop(login, password)
            begin
                self.drop!(login, password)
            rescue NoSuchLoginError, PasswordMismatchError
                nil
            end
        end

        def self.drop!(login, password)
            account = resolve!(login)
            account.authenticate!(login, password)
            @@droppers.each { |dropper| dropper.call(account) }
            @@users.delete(account.id)

            account.account_fields.delete
            account.delete
        end

        def self.register(login, password)
            begin
                register!(login, password)
            rescue LoginExistsError
                nil
            end
        end

        def self.register!(login, password)
            raise LoginExistsError unless self.where(:login => login).empty?

            now  = Time.now
            salt = SecureRandom.base64(256)
            pass = encrypt(salt, password)
            vt   = Digest::SHA2.hexdigest("--#{pass}--#{now.to_s}--")

            account = new
            account.login        = login
            account.salt         = salt
            account.password     = pass
            account.verification = vt
            account.registered   = now
            account.last_login   = now

            account.save
            account
        end

        def self.identify(login, password)
            begin
                identify!(login, password)
            rescue NoSuchLoginError, PasswordMismatchError
                nil
            end
        end

        def self.identify!(login, password)
            account = self.where(:login => login).first
            raise NoSuchLoginError unless account

            account.authenticate!(password)
        end

        def authenticated?()
            @authenticated ||= false
        end

        def authenticates?(password)
            self.password == encrypt(password)
        end

        def authenticate(password)
            begin
                authenticate!(password)
                true
            rescue PasswordMismatchError
                false
            end
        end

        def authenticate!(password)
            pass = encrypt(password)

            if authenticates?(password)
                self.update(:last_login => Time.now, :failed_logins => 0)
                @authenticated = true
            else
                self.update(:failed_logins => self.failed_logins + 1)
                raise PasswordMismatchError
            end

            self
        end

        def logout!
            @authenticated = false
        end

        def verified?
            self.verification.nil?
        end

        def verifies?(verification)
            verification == self.verification
        end

        def verify(verification)
            begin
                verify!(verification)
                true
            rescue BadVerificationError
                false
            end
        end

        def verify!(verification)
            if verifies?(verification)
                self.update(:verification => nil)
            else
                raise BadVerificationError
            end
        end

        def [](key)
            field = account_fields.find { |f| key.to_s == f.key }
            field ? field.value : nil
        end

        def []=(key, value)
            if field = account_fields.find { |f| key.to_s == f.key }
                field.update(:value => value.to_s)
            else
                field = AccountField.new
                field.key   = key.to_s
                field.value = value.to_s

                account_fields << field
            end
        end

        def field_list
            account_fields.collect { |field| field.key }
        end

        def delete_field(key)
            returns unless field = account_fields.find { |f| key.to_s = f.key }
            field.delete
        end

        def users
            @@users[id]
        end

        class LoginExistsError      < Exception; end
        class PasswordMismatchError < Exception; end
        class BadValidationError    < Exception; end
        class NoSuchLoginError      < Exception; end

        class Helper
            def initialize(account)
                @account = account
            end
        end

        #######
        private
        #######

        def self.encrypt(salt, password)
            saltbytes = salt.unpack('m')[0]
            Digest::SHA2.hexdigest(saltbytes + password)
        end

        def encrypt(password)
            self.class.encrypt(self.salt, password)
        end
    end

    class AccountField < Sequel::Model
        many_to_one :account
    end
end
