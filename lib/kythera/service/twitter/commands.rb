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

    # Get a request token from twitter, send user to authorize url
    def do_login(user, params)
        request_token = consumer.get_request_token
        @request_tokens[user] = request_token

        reply  = "To finish OAuth authentication, please visit "
        reply += "#{request_token.authorize_url} and send \2AUTHORIZE <pin>\2"
        reply += "with the resulting PIN code."

        notice(@user.key, user.key, reply)
    rescue OAuth::Error => e
        notice(@user.key, user.key, "Error: #{e}")
    end

    # Authorize a user to twitter
    def do_authorize(user, params)
        request_token = @request_tokens[user]

        access_token  = request_token.get_access_token(
            :oauth_verifier => params[0].to_i)

        @access_tokens[user] = access_token

        who = "\2#{access_token.params[:screen_name]}\2"
        notice(@user.key, user.key, "You are now authorized as #{who}")
    rescue OAuth::Error => e
        notice(@user.key, user.key, "Error: #{e}")
    end
end
