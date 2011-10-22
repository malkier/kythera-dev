# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# db/migrations/004_memoserv_init.rb: create the memoserv database
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.md
#

Sequel.migration do
    change do
        create_table :memoserv_memoranda do
            Integer :from_id
            Integer :to_id, :null => false
            Integer :id,    :null => false

            String :topic, :null => false
            String :memo,  :null => false
            TrueClass :unread, :null => false, :default => true

            # XXX this should have a default in the DB, and not rely on the
            # model to do it. not sure how to set current_timestamp as the
            # default in a DB-agnostic way though.
            DateTime :sent, :null => false

            primary_key [:to_id, :id]
            foreign_key [:from_id], :accounts
            foreign_key [:to_id],   :accounts
        end
    end
end
