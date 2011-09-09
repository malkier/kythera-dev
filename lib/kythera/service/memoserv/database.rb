#
# kythera: services for IRC networks
# lib/kythera/service/memoserv/database.rb: database models for memoserv
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Database
    class Account
        one_to_many :memoserv_memoranda_senders,
                    :class_name => MemorandumService::Memorandum,
                    :foreign_key => :from_id
        one_to_many :memoserv_memoranda_recipients,
                    :class_name => MemorandumService::Memorandum,
                    :foreign_key => :to_id
    end

    module MemorandumService
        class Memorandum < Sequel::Model(:memoserv_memoranda)
            TOPICLEN = $config.memoserv.topic_length || (0..50)

            many_to_one :from, :class_name => Account
            many_to_one :to,   :class_name => Account

            def self.send_memo(from, to, memo, topic = nil)
                from = Account.resolve(from)
                to   = Account.resolve(to)

                topic = memo unless topic
                topic = topic[TOPICLEN]

                memo = new
                memo.from   = from
                memo.to     = to
                memo.topic  = topic
                memo.memo   = memo
                memo.unread = true
                memo.id     = self[:to => to].max + 1
                memo.save

                memo
            end

            def delete_memos(to, *ids)
                # XXX collapse empty IDs, deal with multi-memo deletes
                memo = retrieve_memo!(to, ids[0])
                memo.delete
            end

            def self.read_memo(to, id)
                memo = retrieve_memo!(to, id)
                memo
            end

            def self.mark_read(to, id)
                memo = retrieve_memo!(to, id)
                memo.unread = false
                memo.save
            end

            def self.mark_unread(to, id)
                memo = retrieve_memo!(to, id)
                memo.unread = true
                memo.save
            end

            #######
            private
            #######

            def self.retrieve_memo!(to, id)
                to = Account.resolve!(to)
                memo = self[:to => to, :id => id]
                raise NoSuchMemoID unless memo

                memo
            end
        end

        class Helper < Account::Helper
            def preview_list
                Memorandum[:to => @account].order(:id).each do |memo|
                    yield memo.id, memo.from, memo.topic, memo.unread, memo
                end
            end

            def send_memo(to, memo, topic = nil)
                Memorandum.send_memo(@account, to, memo,topic)
            end

            def delete_memos(*ids)
                Memorandum.delete_memo(@account, *ids)
            end

            def read(id)
                Memorandum.read_memo(@account, id)
            end

            def mark_read(id)
                Memorandum.mark_read(@account, id)
            end

            def mark_unread(id)
                Memorandum.mark_unread(@account, id)
            end
        end

        Account.before_drop do |account|
            Memorandum[:to   => account].delete
            Memorandum[:from => account].update(:from => nil)
        end

        Account.helper [:memoserv, :ms], Helper
    end
end
