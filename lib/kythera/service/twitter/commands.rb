# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/service/twitter/commands.rb: implements twitter's commands
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Copyright (c) 2011 Andrew Herbig <goforit7arh@gmail.com>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

class TwitterService < Service
    private

    HELP_RESPONSE = <<HELP.strip.split("\n")
\2LOGIN\2       Log into twitter
\2AUTHORIZE\2   Authorize to twitter
\2UPDATE\2      Post something to twitter
HELP

    def do_help(user, params)
        HELP_RESPONSE.each do |line|
            notice(@user.key, user.key, line)
        end
    end

    # Get a request token from twitter, send user to authorize url
    def do_login(user, params)
        request_token = consumer.get_request_token
        @request_tokens[user] = request_token

        reply  = "To finish OAuth authentication, please visit "
        reply += "#{request_token.authorize_url} and send \2AUTHORIZE <pin>\2"
        reply += " with the resulting PIN code."

        notice(@user.key, user.key, reply)
    rescue OAuth::Error => e
        notice(@user.key, user.key, "Error: #{e}")
    end

    # Authorize a user to twitter
    def do_authorize(user, params)
        request_token = @request_tokens[user]

        pin = params[0].to_i
        token = request_token.get_access_token(:oauth_verifier => pin)

        @access_tokens[user] = token

        who = "\2#{token.params[:screen_name]}\2"
        notice(@user.key, user.key, "You are now authorized as #{who}")

        @twitters[user] = Twitter.new \
            :consumer_key       => token.consumer.key,
            :consumer_secret    => token.consumer.secret,
            :oauth_token        => token.token,
            :oauth_token_secret => token.secret
    rescue OAuth::Error => e
        notice(@user.key, user.key, "Error: #{e}")
    end

    # Post a tweet to twitter
    def do_update(user, params)
        twitter = @twitters[user]

        twitter.update(params.join(' '))
    end
end
