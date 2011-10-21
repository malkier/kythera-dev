# -*- Mode: Ruby; tab-width: 2; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# test/database/operserv_test.rb: tests the operserv's database API.
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Stephen Belcher <sycobuny@malkier.net>
# Rights to this code are documented in doc/license.txt
#

dir = File.dirname(__FILE__)
require File.expand_path('../teststrap', dir)
require File.expand_path('../../lib/kythera/service/memoserv/database', dir)

check_timestamp = Proc.new do |timestamp, check|
  n = (check || Time.now).to_i
  t = timestamp.to_i

  # close enough I guess, these tests should be all but instantaneous
  n == t or n == (t+1)
end

context :memoserv_db do
  setup do
    $_daemon_block.call
    $_logger_setup.call
    configure_test { service :memoserv }

    $db.run 'DELETE FROM memoserv_memoranda'
    $db.run 'DELETE FROM accounts'

    Database::Account.register('sycobuny@malkier.net', 'password')
    Database::Account.register('rakaur@malkier.net',   'password')
  end

  helper(:klass)    { Database::MemorandumService::Memorandum }
  helper(:sycobuny) { Database::Account[:email => 'sycobuny@malkier.net'] }
  helper(:rakaur)   { Database::Account[:email => 'rakaur@malkier.net']   }
  helper(:ts) do |ts, chk|
    chk = chk.to_i
    ts  = ts.to_i

    # close enough I guess, these tests should be all but instantaneous, but if
    # not 1 second should be enough leeway
    chk == ts or chk == (ts+1)
  end

  context 'sends memos' do
    setup do
      text  = 'Test Memorandum'
      topic = 'Test Topic'
      klass.send_memo(sycobuny, rakaur, text, topic)
    end

    asserts_topic.kind_of Database::MemorandumService::Memorandum
    asserts(:id).equals 1
    asserts(:memo).equals 'Test Memorandum'
    asserts(:topic).equals 'Test Topic'
    asserts(:unread)
    asserts('from sycobuny') { topic.from == sycobuny }
    asserts('to rakaur')     { topic.to   == rakaur   }
    asserts("'sent' set correctly") { ts(topic.sent, Time.now) }
  end

  context 'automatically abbreviates topic' do
    setup do
      text = 'Test Memorandum with a lengthy topic (greater than 50 chars)'
      klass.send_memo(sycobuny, rakaur, text)
    end
    asserts(:topic).equals 'Test Memorandum with a lengthy topic (greater than '
  end

  context 'deletes memos' do
    setup do
      r = rakaur
      s = sycobuny
      t = []

      1.upto(5) do |i|
        text  = "Test Memorandum #{i}"
        topic = "Test Topic #{i}"
        t << klass.send_memo(s, r, text, topic)
      end

      klass.delete_memos(r, 2, 3, 4)
      klass.order(:id).all
    end

    asserts_topic.size 2
    asserts('1st memo is ID 1') { topic[0].id == 1 }
    asserts('2nd memo is ID 2') { topic[1].id == 2 }
    asserts('1st memo text') { topic[0].memo }.equals 'Test Memorandum 1'
    asserts('2nd memo text') { topic[1].memo }.equals 'Test Memorandum 5'

    asserts('deleting a bad ID') do
      klass.delete_memos(rakaur, 3)
    end.raises(Database::MemorandumService::NoSuchMemoIDError)
  end

  context 'reads memos' do
    setup do
      text  = 'Test Memorandum'
      topic = 'Test Topic'
      r     = rakaur
      klass.send_memo(sycobuny, r, text, topic)
      klass.read_memo(r, 1)
    end

    asserts(:id).equals 1
    denies(:unread)

    asserts('reading a bad ID') do
      klass.read_memo(rakaur, 2)
    end.raises(Database::MemorandumService::NoSuchMemoIDError)

    context 'and marks unread' do
      hookup { topic.unread! }
      asserts(:unread)

      context 'and read again' do
        hookup { topic.read! }
        denies(:unread)
      end
    end
  end

  context :helper do
    context 'sends memos' do
      setup do
        sycobuny.ms.send(rakaur, 'Test Memorandum')
      end

      asserts_topic.kind_of Database::MemorandumService::Memorandum
      asserts(:id).equals 1
      asserts(:topic).equals 'Test Memorandum'
      asserts(:memo).equals  'Test Memorandum'
    end

    context 'reads memos' do
      setup do
        r = rakaur
        sycobuny.ms.send(r, 'Test Memorandum')
        r.ms.read(1)
      end

      asserts_topic.kind_of Database::MemorandumService::Memorandum
      asserts(:id).equals 1
      denies(:unread)

      context 'and marks unread' do
        setup do
          r = rakaur
          r.ms.mark_unread(1)
          klass[:to => r, :id => 1] # need to refresh this from the DB
        end
        asserts(:unread)

        context 'and marks read again' do
          setup do
            r = rakaur
            r.ms.mark_read(1)
            klass[:to => r, :id => 1] # need to refresh this from the DB
          end
          denies(:unread)
        end
      end
    end

    context 'previews memos' do
      setup do
        r = rakaur
        s = sycobuny
        1.upto(3) do |i|
          s.ms.send(r, "Test Memo #{i}")
        end
        r.ms.read(2)
        r
      end

      asserts('iterates through memos') do
        r = rakaur
        s = sycobuny
        memos = klass.filter(:to => r).order(:id).all

        memo2 = klass
        check = [
          [1, s, "Test Memo 1", true,  true, memos[0]],
          [2, s, "Test Memo 2", false, true, memos[1]],
          [3, s, "Test Memo 3", true,  true, memos[2]]
        ]

        values = []
        r.ms.preview_list do |*args|
          args[4] = ts(args[4], Time.now)
          values << args
        end

        check == values
      end
    end
  end

  context 'cleaning up...' do
    hookup do
      $db.run 'DELETE FROM memoserv_memoranda'
      $db.run 'DELETE FROM accounts'
    end
  end
end
