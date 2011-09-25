#
# kythera: services for IRC networks
# lib/kythera/protocol/unreal/user.rb: UnrealIRCd-specific User class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# This subclasses the base User class in `kythera/user.rb`
class Protocol::Unreal::User < User
    # Unreal's user modes
    @@user_modes = { 'A' => :server_admin,
                     'a' => :services_admin,
                     'B' => :bot,
                     'C' => :co_admin,
                     'd' => :deaf,
                     'G' => :censored,
                     'g' => :oper_talk,
                     'H' => :hide_ircop,
                     'h' => :helper,
                     'i' => :invisible,
                     'N' => :net_admin,
                     'O' => :local_oper,
                     'o' => :global_oper,
                     'p' => :hide_whois_channels,
                     'q' => :unkickable,
                     'R' => :registered_privmsg,
                     'r' => :registered,
                     'S' => :service,
                     's' => :receives_snotices,
                     'T' => :no_ctcp,
                     't' => :vhost,
                     'V' => :webtv,
                     'v' => :dcc_infection_notices,
                     'W' => :see_whois,
                     'w' => :wallop,
                     'x' => :hidden_host,
                     'z' => :ssl }

     # The user's timestamp
     attr_accessor :timestamp

     # The user's virtual host/spoof
     attr_reader :vhost

     # The user's fake/pseudorandom hostmask (for DoS protection)
     attr_reader :cloakhost

    # Creates a new user and adds it to the list keyed by nick
    def initialize(server, nn, un, hn, rn, umodes, ts, vhost = nil, cloak = nil)
        @timestamp = ts.to_i
        @vhost     = vhost || host
        @cloakhost = cloak || host

        super(server, nn, un, hn, rn, umodes)
    end

    # Is this user an IRC operator?
    #
    # @return [Boolean] true or false
    #
    def operator?
        @modes.include?(:global_oper)
    end
end
