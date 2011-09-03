#
# kythera: services for IRC networks
# lib/kythera/protocol/send.rb: implements protocol basics
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.txt
#

module Protocol
    private

    # :source PRIVMSG target :message
    def send_privmsg(source, target, message)
        raw ":#{source} PRIVMSG #{target} :#{message}"
    end

    # :source NOTICE target :message
    def send_notice(source, target, message)
        raw ":#{source} NOTICE #{target} :#{message}"
    end

    # :user QUIT :reason
    def send_quit(user, reason)
        raw ":#{user} QUIT :#{reason}"
    end

    # :user TOPIC target :topic
    def send_topic(user, target, topic)
        raw ":#{user} TOPIC #{target} :#{topic}"
    end

    # :user JOIN channel
    def send_join(user, channel)
        raw ":#{user} JOIN #{channel}"
    end

    # :user PART channel :reason
    def send_part(user, channel, reason = 'leaving')
        raw ":#{user} PART #{channel} :#{reason}"
    end
end
