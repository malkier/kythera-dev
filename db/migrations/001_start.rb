# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# db/migrations/001_start.rb: create the database
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

Sequel.migration do
    change do
        create_table :accounts do
            primary_key :id

            # Their unique id is their email address
            String :email,    :unique => true, :null => false
            String :salt,     :unique => true, :null => false
            String :password, :null   => false

            # For account verification
            String :verification

            # Some time records
            DateTime :registered, :null => false
            DateTime :last_login

            # For tracking the failed login attempts
            Integer :failed_logins, :null => false, :default => 0

            # Index the login for faster lookups
            index :email
        end

        create_table :account_fields do
            Integer :account_id, :null => false
            String  :key
            String  :value

            unique [:account_id, :key]
            primary_key [:account_id, :key]
            foreign_key [:account_id], :accounts
        end
    end
end
