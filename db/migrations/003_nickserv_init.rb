# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# db/migrations/003_nickserv_init.rb: create the nickserv database
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

Sequel.migration do
    change do
        create_table :nickserv_nicknames do
            String  :nickname, :null => false, :unique => true
            Integer :account_id, :null => false

            primary_key [:nickname]
            foreign_key [:account_id], :accounts
        end
    end
end
