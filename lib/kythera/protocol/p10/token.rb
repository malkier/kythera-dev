# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/token.rb: implements the P10 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

# Defines the P10 tokens and other special methods
module Protocol::P10
    include Protocol

    # The list of chars in p10's braindead base64 implementation
    P10_CHR = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789[]"

    # P10 token map
    Tokens = { :P    => :privmsg,
               :H    => :who,
               :W    => :whois,
               :X    => :whowas,
               :USER => :user,
               :N    => :nick,
               :S    => :server,
               :LIST => :list,
               :T    => :topic,
               :I    => :invite,
               :V    => :version,
               :Q    => :quit,
               :SQ   => :squit,
               :D    => :kill,
               :F    => :info,
               :LI   => :links,
               :R    => :stats,
               :HELP => :help,
               :Y    => :error,
               :A    => :away,
               :CO   => :connect,
               :MAP  => :map,
               :G    => :ping,
               :Z    => :pong,
               :OPER => :oper,
               :PA   => :pass,
               :WA   => :wallops,
               :DS   => :desynch,
               :TI   => :time,
               :SE   => :settime,
               :RI   => :rping,
               :RO   => :rpong,
               :E    => :names,
               :AD   => :admin,
               :TR   => :trace,
               :O    => :notice,
               :WC   => :wallchops,
               :CP   => :cprivmsg,
               :CN   => :cnotice,
               :J    => :join,
               :L    => :part,
               :LI   => :lusers,
               :MO   => :motd,
               :M    => :mode,
               :K    => :kick,
               :U    => :silence,
               :GL   => :gline,
               :B    => :burst,
               :C    => :create,
               :DE   => :destruct,
               :EB   => :end_of_burst,
               :EA   => :end_of_burst_ack,
               :JU   => :jupe,
               :OM   => :opmode,
               :CM   => :clearmode,
               :AC   => :account,

               :USERHOST => :userhost,
               :USERIP   => :userip,
               :ISON     => :ison,
               :SQUERY   => :squery,
               :SERVLIST => :servlist,
               :SERVSET  => :servset,
               :REHASH   => :rehash,
               :CLOSE    => :close,
               :DIE      => :die,
               :HASH     => :hash,
               :DNS      => :dns,
               :PROTO    => :proto }

    # The same tokens reversed, for SENDING commands
    Tokens.update(Tokens.invert)

    private

    # works for both sids and uids
    # returns the number corresponding to the id given
    def self.base64_decode(s)
        s = s.dup
        n = 0

        until s.empty?
            n *= P10_CHR.size
            n += P10_CHR.index(s[0])
            s = s[REMOVE_FIRST]
        end

        n
    end

    # returns the id corresponding to the given number
    def self.base64_encode(n, size)
        s = ""

        until n == 0
            n, mod = n.divmod(P10_CHR.size)
            s = P10_CHR[mod] + s
        end

        s.rjust(size, P10_CHR[0])
    end

    # returns the sid for the given number
    def self.integer_to_sid(n)
        self.base64_encode(n, 2)
    end

    # returns the uid for the given number
    def self.integer_to_uid(n)
        self.base64_encode(n, 3)
    end
end
