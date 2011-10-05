# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/memoserv/database.rb: database models for memoserv
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.md
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

    #
    # This module creates, reads, and deletes memorandums sent between users of
    # the system. It assumes everyone wants the ability to send and receive
    # memos, and does not allow for blocking users (currently). There are only a
    # few fields to a memo: to, from, unread, topic, and memo.
    #
    module MemorandumService
        #
        # Base exception class for any MemorandumService errors. Should probably
        # not be used directly.
        #
        # @private
        #
        class Error < Exception; end

        #
        # When lookups of memo IDs fail, the class will throw this error.
        #
        class NoSuchMemoIDError < Error; end

        #
        # This is the class that drives most of the work on the database side of
        # this service.
        #
        class Memorandum < Sequel::Model(:memoserv_memoranda)
            #
            # This is the maximum length for a topic. It should be short enough
            # that one could reasonably assume that it could fit on a line from
            # IRC with the sender's login ID (typically the length of an email
            # address).
            #
            TOPICLEN = $config.memoserv.topic_length || (0..50)

            many_to_one :from, :class_name => Account
            many_to_one :to,   :class_name => Account

            #
            # Sends a memo from one account to another. The topic can be
            # auto-generated from the first `TOPICLEN` characters of the memo
            # itself, and this may be the prefered method for a particular
            # implementation. The memos are given distinct IDs per account, in
            # order of receipt.
            #
            # @param [Account] from The account sending the memo
            # @param [Account] to The account receiving the memo
            # @param [String] memo The memo text itself
            # @param [String] topic The optional topic of the memo
            # @example
            #   from = 'rakaur@malkier.net'
            #   to   = 'sycobuny@malkier.net'
            #   memo = <<-MEMO
            #     Hey, Steve. I just thought I'd let you know you were awesome.
            #     Cause you're pretty awesome.
            #   MEMO
            #   topic = 'How Awesome You Are'
            #   Memorandum.send(from, to, memo, topic)
            #
            def self.send_memo(from, to, memo, topic = nil)
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

            #
            # Delete memos from an account. This method takes any number of IDs,
            # but raises an error if any of them are not valid IDs.
            #
            # @param [Account] to The memo recipient
            # @param [Integer] *ids The memo IDs
            # @raise [NoSuchMemoIDError] If any memo IDs given are invalid
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   Memorandum.delete_memos(account, 5)
            #
            def self.delete_memos(to, *ids)
                transaction do
                    to = Account.resolve(to)
                    ids.collect! { |id| id.to_i }

                    ds = self[:to => to, :id => ids]
                    raise NoSuchMemoIDError unless ds.count == ids.length

                    ds.delete

                    min_affected = ids.sort[0]
                    ds = self[:to => to].filter{ :id > min_affected }

                    x = min_affected
                    ds.each do |memo|
                        memo.update(:id => x)
                        x += 1
                    end
                end
            end

            #
            # Retrieves a memo object, and sets the memo to being "read". Raises
            # an error if the memo ID given is invalid.
            #
            # @param [Account] to The memo recipient
            # @param [Integer] id The memo ID
            # @return [Memorandum] The requested memo
            # @raise [NoSuchMemoIDError] If the memo ID given was invalid
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   memo = Memorandum.read_memo(account, 5)
            #
            def self.read_memo(to, id)
                memo = self[:to => to, :id => id].first
                raise NoSuchMemoIDError unless memo

                memo.read!
                memo
            end

            #
            # Marks a memo as read and saves it to the database.
            #
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   memo = Memorandum.read_memo(account, 5)
            #   memo.read! # redundant in this case, `read_memo` did this by now
            #
            def read!
                self.unread = false
                save
            end

            #
            # Marks a memo as unread and saves it to the database.
            #
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   memo = Memorandum.read_memo(account, 3)
            #   memo.unread!
            #
            def unread!
                self.unread = true
                save
            end
        end

        #
        # Helper for Account objects.
        #
        class Helper < Account::Helper
            #
            # Iterates through the memos for the account and yields relevant
            # values to the block given. Values passed are the memo ID, the
            # account that sent the memo, the memo topic, whether the memo is
            # unread, and the memo object itself.
            #
            # @example
            #   user.account.ms.preview_list do |id, from, topic, unread|
            #     msg = unread ? "\002" : ''
            #     msg = "%2d. (%s) - %s" [id, from.login, topic]
            #
            #     user.send_privmsg(msg)
            #   end
            #
            def preview_list
                Memorandum[:to => @account].order(:id).each do |memo|
                    yield memo.id, memo.from, memo.topic, memo.unread, memo
                end
            end

            #
            # Shortcut to send a memo.
            #
            # @param [Account] to The account to send the memo to
            # @param [String] memo The memo contents
            # @param [String] topic The optional topic
            # @return [Memo] The newly-sent memo
            # @example
            #   account = Account.resolve('rakaur@malkier.net')
            #   to      = Account.resolve('sycobuny@malkier.net')
            #   memo    = <<-MEMO
            #     FYI, I'm changing how you log in to moridin. It'll no longer
            #     allow password-based auth. You need to make sure you copy your
            #     pubkey over by Tuesday or you won't be able to log in anymore.
            #   MEMO
            #   topic   = "You need to update moridin's SSH key"
            #   account.ms.send(to, memo, topic)
            #
            def send(to, memo, topic = nil)
                Memorandum.send_memo(@account, to, memo,topic)
            end

            #
            # Shortcut to delete memos.
            #
            # @param [Integer] *ids The memo IDs to delete
            # @example
            #   account = Account.resolve('sycobuny@malkier.net')
            #   ids     = [1, 5, 10]
            #   account.ms.delete(*ids)
            #
            def delete(*ids)
                Memorandum.delete_memo(@account, *ids)
            end

            #
            # Shortcut to read a memo.
            #
            # @param [Integer] id The memo ID to read
            # @return [Memorandum] The memo to read
            # @raise [NoSuchMemoIDError] If the memo ID given was invalid
            # @example
            #   account = Account.resolve('rakaur@malkier.net')
            #   memo = account.ms.read(3)
            #
            def read(id)
                Memorandum.read_memo(@account, id)
            end

            #
            # Shortcut to mark a memo as read.
            #
            # @param [Integer] id The memo ID to mark as read
            # @raise [NoSuchMemoIDError] If the memo ID given was invalid
            # @example
            #   account = Account.resolve('rakaur@malkier.net')
            #   account.ms.mark_read(2)
            #
            def mark_read(id)
                Memorandum[:account => @account, :id => id].read!
            end

            #
            # Shortcut to mark a memo as unread.
            #
            # @param [Integer] id The memo ID to mark as unread
            # @raise [NoSuchMemoIDError] If the memo ID given was invalid
            # @example
            #   account = Account.resolve('rakaur@malkier.net')
            #   account.ms.mark_unread(3)
            #
            def mark_unread(id)
                Memorandum[:account => @account, :id => id].unread!
            end
        end

        Account.before_drop do |account|
            Memorandum[:to   => account].delete
            Memorandum[:from => account].update(:from => nil)
        end

        Account.helper [:memoserv, :ms], Helper
    end
end
