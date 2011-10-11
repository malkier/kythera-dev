# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# extensions/diakofti/send.rb: methods for sending data
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

module Diakofti::Senders
    private

    def send_stanza(stanza)
        @sendq << stanza
    end

    def send_error(error, args = {})
        stanza = { 'type' => error.to_s }.merge(args)

        @sendq << { 'error' => stanza }

        $eventq.post(:extension_socket_dead, @socket)
    end

    def send_stanza_error(type, error, args = {})
       stanza = {
           type => {
               'error' => { 'type' => error.to_s }.merge(args)
           }
       }

       send_stanza(stanza)
    end

    def send_start(args = {})
        start = {
            'start' => { 'version' => '1.0.0' }.merge(args)
        }

        send_stanza(start)
    end

    def send_features
        stanza   = { 'features'   => {}        }
        starttls = { 'required'   => false     }
        sasl     = { 'mechanisms' => ['plain'] }

        stanza['features']['starttls'] = starttls unless @state.tls
        stanza['features']['sasl']     = sasl     unless @state.sasl

        send_stanza(stanza)
    end

    def send_starttls(args)
       stanza = { 'starttls' => args }
       send_stanza(stanza)
    end

    def send_authenticate(args)
        stanza = { 'authenticate' => args }
        send_stanza(stanza)
    end
end
