# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/send.rb: implements protocol basics
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

module Protocol
    private

    # :origin OPERWALL :message
    def send_wallop(origin, message)
        assert { { :origin => String, :message => String } }

        raw ":#{origin} OPERWALL :#{message}"
    end

    # :origin PRIVMSG target :message
    def send_privmsg(origin, target, message)
        assert { { :origin => String, :target => String, :message => String } }

        raw ":#{origin} PRIVMSG #{target} :#{message}"
    end

    # :origin NOTICE target :message
    def send_notice(origin, target, message)
        assert { { :origin => String, :target => String, :message => String } }

        raw ":#{origin} NOTICE #{target} :#{message}"
    end

    # :user QUIT :reason
    def send_quit(origin, reason)
        assert { { :origin => String, :reason => String } }

        raw ":#{origin} QUIT :#{reason}"
    end

    # :origin TOPIC target :topic
    def send_topic(origin, target, topic)
        assert { { :origin => String, :target => String, :topic => String } }

        raw ":#{origin} TOPIC #{target} :#{topic}"
    end

    # :user JOIN target
    def send_join(origin, target)
        assert { { :origin => String, :target => String } }

        raw ":#{origin} JOIN #{target}"
    end

    # :origin PART target :reason
    def send_part(origin, target, reason)
        assert { { :origin => String, :target => String, :reason => String } }

        raw ":#{origin} PART #{target} :#{reason}"
    end
end
