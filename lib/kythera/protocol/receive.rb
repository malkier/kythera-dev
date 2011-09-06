#
# kythera: services for IRC networks
# lib/kythera/protocol/receive.rb: implements protocol basics
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

module Protocol
    private

    # Handles an incoming JOIN
    #
    # parv[0] -> channel name
    #
    def irc_join(origin, parv)
        user, channel = find_user_and_channel(origin, parv[0], :JOIN)
        return unless user and channel

        # Add them to the channel
        channel.add_user(user)
    end

    # Handles an incoming PART
    #
    # parv[0] -> channel name
    #
    def irc_part(origin, parv)
        user, channel = find_user_and_channel(origin, parv[0], :PART)
        return unless user and channel

        # Delete them from the channel
        channel.delete_user(user)
    end

    # Handles an incoming QUIT
    #
    # parv[0] -> quit message
    #
    def irc_quit(origin, parv)
        unless user = $users.delete(origin)
            $log.error "received QUIT for unknown user: #{origin}"
            return
        end

        user.server.delete_user(user)
        $eventq.post(:user_deleted, user, parv[0])

        $log.debug "user quit: #{user} [#{origin}]"
    end

    # Handles an incoming PRIVMSG
    #
    # parv[0] -> target
    # parv[1] -> message
    #
    def irc_privmsg(origin, parv)
        return if parv[0][0].chr == '#'

        # Look up the sending user
        user = $users[origin]

        # Which one of our clients was it sent to?
        srv = $services.find do |s|
            if s.respond_to?(:user)
                s.user.origin.irc_downcase == parv[0].irc_downcase
            end
        end

        # Send it to the service (if we found one)
        srv.send(:irc_privmsg, user, parv[1].split(' ')) if srv
    end

    # Handles an incoming KICK
    #
    # parv[0] -> channel name
    # parv[1] -> kicked user
    # parv[2] -> kick reason
    #
    def irc_kick(origin, parv)
        user, channel = find_user_and_channel(parv[1], parv[0], :KICK)
        return unless user and channel

        # Delete the user from the channel
        channel.delete_user(user)
    end
end
