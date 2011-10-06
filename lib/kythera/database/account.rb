# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/database/account.rb: core account and accountfield models
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Database
    #
    # This class provides the core functionality of an account system, which can
    # be proxied by any number of services in any number of ways. It allows for
    # registering new lookup methods at runtime, so that a service can register
    # a new way to find users if it needs or wants to. It also provides a hook
    # to ensure accounts can clean up their own models before an account that
    # they depend on is dropped.
    #
    # Another feature is account validation. While this class does not enforce
    # any restrictions on logging in or performing any functions before an
    # account is validated, other services may access that information and
    # restrict the users however they would like.
    #
    class Account < Sequel::Model
        one_to_many :account_fields

        #
        # The base error class for anything that might go wrong in Account. It
        # should probably not be used directly.
        #
        # @private
        #
        class Error < Exception; end

        #
        # When a login is already registered and somone attempts to re-register
        # it, this error will be raised.
        #
        class LoginExistsError          < Exception; end

        #
        # When a bad password is given, this error will be raised.
        #
        class PasswordMismatchError     < Exception; end

        #
        # When an attempt is made to authenticate on an Account object that is
        # already authenticated, this error will be raised.
        #
        class AlreadyAuthenticatedError < Exception; end

        #
        # When a bad validation token is given, this error will be raised.
        #
        class BadVerificationError      < Exception; end

        #
        # When someone attempts to perform a function on a bad login, this error
        # will be raised.
        #
        class NoSuchLoginError          < Exception; end

        #
        # When someone attempts to resolve a value that can't be resolved, this
        # error will be raised.
        #
        class ResolveError              < Exception; end

        #
        # The list of resolve handlers which will be called by Account.resolve.
        #
        # @private
        #
        @@resolvers = []

        #
        # The list of handlers that will be called to clean up the database
        # state before an account is dropped.
        #
        # @private
        #
        @@droppers  = []

        #
        # A class-wide hash so that non-cached Sequel Model objects can still
        # refer to the same list of users if they're the same account.
        #
        # @private
        #
        @@users     = {}

        #
        # Initializes the object, registering an array for storing related user
        # objects if one doesn't already exist, and creating an empty helper
        # array for later.
        #
        # @private
        #
        def initialize(*args)
            super

            @@users[id] ||= []
            @helpers = {}
        end

        #
        # Registers a resolve method to be run if normal resolution of the
        # account is not possible. This allows something like a Nickname to be
        # used to resolve an account, rather than their primary services email.
        # Each block is run in the order added, and the first one to return a
        # result wins. They are passed the object that was requested to resolve.
        #
        # @param [Proc] block The code to run if the resolve does not work.
        # @example
        #   Account.register_resolver do |acct_to_resolve|
        #     if acct_to_resolve == 'rakaur'
        #       Account[:email => 'rakaur@malkier.net']
        #     end
        #   end
        #
        def self.register_resolver(&block)
            @@resolvers << block
        end

        #
        # Registers a handler to run before an account is dropped. This method
        # exists primarily to ensure that dependent objects are removed from the
        # database, lest the removal of the account row fail. Core dependencies
        # (such as all AccountField rows) are removed automatically, but all
        # other relations, such as nicknmes in a NicknameService, must remove
        # themselves.
        #
        # @param [Proc] block The code to run before dropping the account.
        # @example
        #   Account.before_drop do |account|
        #     $my_logger.warn("Dropping #{account.email}!")
        #     MyRelatedClass[:account => account].delete
        #   end
        #
        def self.before_drop(&block)
            @@droppers << block
        end

        #
        # Registers a `helper` class, which is essentially a series of methods
        # that can be run on an Account object. The base of the helper class
        # is recommended to be a descendent of Account::Helper, but it is not
        # required. The class given is instantiated with the account object
        # that is being referenced. Account::Helper turns this into @account
        # automatically.
        #
        # @param [Array] aliases The methods to register to Account
        # @param [Symbol, #to_sym] aliases The method to register to Account
        # @param [Class] klass The class to instantiate
        # @example
        #   Account.helper [:my_service], MyService::Helper
        #
        def self.helper(aliases, klass)
            aliases = *aliases
            prime_alias = aliases.shift.to_sym

            define_method(prime_alias) do
                @helpers[prime_alias] ||= klass.new(self)
            end
            aliases.each { |a| define_method(a.to_sym) { prime_alias } }
        end

        #
        # Registers a user with a given email and password. The password should
        # be plaintext; it is hashed by this library before storage in the
        # database.
        #
        # @param [String] email The account's email (login ID)
        # @param [String] password The password to access the account
        # @return [Account] The newly-minted account
        # @raise [LoginExistsError] If the email given already exists
        # @example
        #   account = Account.register('rakaur@malkier.net', 'steveisawesome')
        #
        def self.register(email, password)
            raise LoginExistsError unless self.where(:email => email).empty?

            now  = Time.now
            salt = SecureRandom.base64(192)
            pass = hash_password(salt, password)
            vt   = SecureRandom.base64(12)

            account = new
            account.email        = email
            account.salt         = salt
            account.password     = pass
            account.verification = vt
            account.registered   = now
            account.last_login   = now

            account.save
            account
        end

        #
        # Resolves a variety of inputs to an Account, if possible. It can
        # initially be an Account object, an Integer representing the database
        # serial ID, or the String representing the login ID. If all of these
        # methods fail, all of the blocks that have been registered with
        # Account.register_resolver are called in order of registration, before
        # ultimately giving up and raising an error.
        #
        # @param [Object] acct_to_resolve The input to resolve
        # @raise [ResolveError] If the account could not be determined
        # @example
        #   account = Account.resolve('rakaur@malkier.net')
        #   account = Account.resolve(account)    # returns account
        #   account = Account.resolve(132)
        #   account = Account.resolve('rakaur') # with registered handler
        #
        def self.resolve(acct_to_resolve)
            return acct_to_resolve if acct_to_resolve.kind_of?(self)

            if acct_to_resolve.kind_of?(Integer)
                account = Account[acct_to_resolve] rescue nil
                return account if account
            end

            account = Account[:email => acct_to_resolve.to_s] rescue nil
            return account if account

            @@resolvers.each do |resolver|
                account = resolver.call(acct_to_resolve)
                return account if account
            end

            raise ResolveError, acct_to_resolve
        end

        #
        # Verifies an email against a given password. The password should be
        # given as plaintext.
        #
        # @param [Object] email The email (or resolvable object) to be logged in
        # @param [String] password The password for the login
        # @return [Account] The account that was verified
        # @raise [ResolveError] When no login matches what was requested
        # @raise [PasswordMismatchError] When the password is wrong
        # @example
        #   account = Account.authenticate('rakaur', 'steveisawesome')
        #
        def self.authenticate(email, password)
            account = resolve(email).authenticate(password)
        end

        #
        # Drops an account that was registered. This method is an alias to the
        # `admin_drop` method, which allows for a user who is not logged in to
        # drop his or her own account. For further documentation, see the full
        # admin_drop method.
        #
        # @param [Object] email The email (or resolvable object) to be dropped
        # @param [String] password The password for the login
        # @raise [ResolveError] When no login matches what was requested
        # @raise [PasswordMismatchError] When the password is wrong
        # @example
        #   Account.drop('rakaur', 'steveisawesome')
        #
        def self.drop(email, password)
            account = authenticate(email, password)
            admin_drop(account)
        end

        #
        # Drops an account that was registered. This method does not check any
        # credentials, and is meant for use by admins only. It calls all of the
        # handlers registered with the `before_drop` hook, in order of their
        # registration. Their return value is not checked. However, if they
        # fail to remove all related data, then a mysterious Sequel Database
        # error of any given variety might be raised.
        #
        # @param [Object] email The email (or resolvable object) to be dropped
        # @raise [ResolveError] When no login matches what was requested
        # @example
        #   Account.admin_drop('rakaur@malkier.net')
        #
        def self.admin_drop(email)
            account = resolve(email)
            @@droppers.each { |dropper| dropper.call(account) }
            @@users.delete(account.id)

            AccountField.filter{ {:account => account} }.delete
            account.delete
        end

        #
        # Whether a given account object has authenticated (also referred to as
        # logged in or identified) to the system. Note that each newly-created
        # account object (even for accounts that have previously authenticated)
        # the default state is no.
        #
        # @return [True, False] Whether the account has authenticated
        #
        #   account = Account.authenticate('rakaur', 'steveisawesome')
        #   account.authenticated?  # true
        #   account2 = Account.resolve('rakaur')
        #   account2.authenticated? # false
        #
        def authenticated?
            @authenticated ||= false
        end

        #
        # Whether a given account would authenticate if given this password.
        # Note that this does not alter the state of the object, just returns
        # true or false depending on whether a call to `authenticate` would
        # succeed.
        #
        # @param [String] password The password to verify
        # @return [True, False] Whether the password authenticates
        # @example
        #   account = Account.resolve('rakaur')
        #   account.authenticates?('steveisawesome') # true
        #   account.authenticated?                   # false
        #   account.authenticates?('stevesucks')     # false
        #
        def authenticates?(password)
            self.password == hash_password(password)
        end

        #
        # Sets the account to authenticated if the password matches. Note that
        # this method also automatically resets account.failed_logins and
        # account.last_login. So, if these values are of use to you, you should
        # retrieve them before calling this method. This method will not allow
        # a user to re-authenticate if they have already authenticated. If they
        # wish to attempt to do so (for whatever reason), then the logout!
        # method should be called first.
        #
        # @param [String] password The password to verify
        # @return [Account] The account object (self)
        # @raise [PasswordMismatchError] If the password did not match
        # @raise [AlreadyAuthenticatedError] If there's an attempt to re-auth
        # @example
        #   account = Account.resolve('rakaur')
        #   account.authenticate('steveisawesome')
        #
        def authenticate(password)
            raise AlreadyAuthenticatedError if authenticated?

            if authenticates?(password)
                self.update(:last_login => Time.now, :failed_logins => 0)
                @authenticated = true
            else
                self.update(:failed_logins => self.failed_logins + 1)
                raise PasswordMismatchError
            end

            self
        end

        #
        # Sets the account to no longer be authenticated.
        #
        # @example
        #   account = Account.authenticate('rakaur', 'steveisawesome')
        #   account.authenticated? # true
        #   account.logout!
        #   account.authenticated? # false
        #
        def logout!
            @authenticated = false
        end

        #
        # Returns true when the account has been verified. This defaults to
        # false currently, as verification is assumed. However, verification
        # has no impact on what the account holder can do in this class. It is
        # up to other modules to determine what verification or lack thereof
        # means.
        #
        # @return [True, False] Whether the account has been verified
        # @example
        #   account = Account.register('sycobuny@malkier.net', 'whooparty')
        #   account.verified? # false
        #
        def verified?
            self.verification.nil?
        end

        #
        # Returns true when the given verification token would successfully
        # verify the account. Note that this method does not actually verify
        # the account, just checks that the given token would if passed to
        # `Account#verify`.
        #
        # @param [String] verification The verification token
        # @return [True, False] Whether the account would verify with the token
        # @example
        #   account = Account.resolve('sycobuny@malkier.net')
        #   account.verifies?('this is a pretend good token') # true
        #   account.verified?                                 # false
        #   account.verifies?('this is a pretend bad token')  # false
        #   account.verified?                                 # false
        #
        def verifies?(verification)
            verification == self.verification
        end

        #
        # Verifies the account. Once an account is verified, it will not be
        # "un-verified" unless acted on by an outside force. Attempting to
        # pass the same value twice to this function will therefore result in
        # an error, as no validation token will match.
        #
        # @param [String] verification The verification token
        # @raise [BadVerificationError] If the verification token was wrong
        # @example
        #   account = Account.resolve('sycobuny@malkier.net')
        #   account.verified? # false
        #   account.verify('this is a pretend good token') # true
        #   account.verified? # true
        #   account.verify('this is a pretend good token') # Exception raised!
        #
        def verify(verification)
            if verifies?(verification)
                self.update(:verification => nil)
            else
                raise BadVerificationError
            end
        end

        #
        # Returns an arbitrary value that was stored in the database along with
        # the Account. These fields can be used to extend an Account without
        # creating an entirely new dependent model. Keys are unique to each
        # Account, so two accounts can have the same key with different values.
        # The keys must be strings, or convertible to strings, as well as the
        # values.
        #
        # @param [String, #to_s] string,
        # @return [String] The value associated with the key
        # @example
        #   account = Account.resolve('rakaur')
        #   account[:website] # 'http://www.malkier.net/'
        #
        def [](key)
            return super if self.class.columns.include?(key)

            field = account_fields.find { |f| key.to_s == f.key }
            field ? field.value : nil
        end

        #
        # Assigns an arbitrary value that can be stored in the database along
        # with the Account. These fields are converted into string values, as
        # no other datatypes can be put into a single field. The keys must also
        # be strings or coercible. It's worth noting that the nil value passed
        # in would be converted into an empty string. To truly remove a field,
        # one should call `Account#delete_field`.
        #
        # @param [String, #to_s] key The key to associate with the Account
        # @param [String, #to_s] value The value to associate with the key
        # @return [String] The value that was stored
        # @example
        #   account = Account.resolve('rakaur@malkier.net')
        #   account[:website] = 'http://www.malkier.net/'
        #
        def []=(key, value)
            return super if self.class.columns.include?(key)
            return delete_field(key) unless value

            if field = account_fields.find { |f| key.to_s == f.key }
                field.update(:value => value.to_s)
            else
                field = AccountField.new
                field.account = self
                field.key     = key.to_s
                field.value   = value.to_s
                field.save
            end

            value.to_s
        end

        #
        # Returns a list of all the arbitrary fields (ie, not included as part
        # of the base model) that are registered to this Account.
        #
        # @return [Array] The list of fields
        # @example
        #   account = Account.resolve('rakaur')
        #   account.field_list # ['website', 'love_for_steve']
        #   account[:love_for_steve] # 'infinite'
        #
        def field_list
            account_fields.collect { |field| field.key }
        end

        #
        # Removes a field from the list of arbitrary fields. This is different
        # than setting the field to nil, as it actually removes a record from
        # the database rather than simply updating it.
        #
        # @param [String, #to_s] key The key to delete
        # @return [AccountField] The just-deleted field
        # @example
        #   account = Account.resolve('rakaur')
        #   account.delete_field(:love_for_steve) # should be an error but isn't
        #
        def delete_field(key)
            return unless field = account_fields.find { |f| key.to_s == f.key }
            ret = field.delete

            # force reloading of the account fields
            account_fields(true)

            ret
        end

        #
        # Returns a list of all of the users who have had this account
        # associated with their objects. This is to allow multiple users to
        # log in simultaneously to the same account, while still allowing for
        # broadcast messages when anything happens to them or their account.
        # It works the way it does because Sequel does not cache database
        # objects, which, strangely enough, mostly works in our favor.
        #
        # @return [Array] The list of active users of this account
        # @example
        #   user.account = Account.authenticate('rakaur', 'steveisawesome')
        #   user.account.users << user
        #   account = Account.resolve('rakaur')
        #   account.users # [user]
        #
        def users
            @@users[id]
        end

        #
        # This class simplifies helper generation slightly by making the
        # associated Account object available automatically in @account.
        #
        class Helper
            #
            # Initialize a new Helper for a given account.
            #
            # @param [Account] account The account to register to this helper.
            # @private
            #
            def initialize(account)
                @account = account
            end
        end

        #######
        private
        #######

        #
        # Hashes a plaintext password using a salt.
        #
        # @private
        # @param [String] salt The salt used to hash the password
        # @param [String] password The plaintext password to be hashed
        # @return [String] The hashed password
        #
        def self.hash_password(salt, password)
            saltbytes = salt.unpack('m')[0]
            Digest::SHA2.hexdigest(saltbytes + password)
        end

        #
        # Hashes a plaintext password
        #
        # @private
        # @param [String] password The plaintext password to be hashed
        # @return [String] The hashed password
        #
        def hash_password(password)
            self.class.hash_password(self.salt, password)
        end
    end

    #
    # This is the model that represents an arbitrary field for an account in the
    # database. Probably should not be used directly.
    #
    # @private
    #
    class AccountField < Sequel::Model
        many_to_one :account
    end
end
