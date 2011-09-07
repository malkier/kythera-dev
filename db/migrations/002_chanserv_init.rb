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
        create_table :chanserv_channels do
            primary_key :id

            String  :name,        :null => false, :unique => true
            Integer :founder_id,  :null => false
            Integer :successor_id

            DateTime :registered, :null => false
            DateTime :last_activity

            foreign_key [:founder_id], :accounts
            foreign_key [:successor_id], :accounts
        end

        create_table :chanserv_privileges do
            Integer :channel_id, :null => false
            Integer :account_id, :null => false
            String  :privilege,  :null => false
            String  :value

            foreign_key [:channel_id], :chanserv_channels
            foreign_key [:account_id], :accounts

            primary_key [:channel_id, :account_id, :privilege]
        end

        create_table :chanserv_flags do
            Integer :channel_id, :null => false
            String  :flag,       :null => false
            String  :value

            foreign_key [:channel_id], :chanserv_channels

            primary_key [:channel_id, :flag]
        end
    end
end
