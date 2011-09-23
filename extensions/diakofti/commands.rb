#
# kythera: services for IRC networks
# extensions/diakofti/commands.rb: command handlers
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

module Diakofti::CommandHandlers
    private

    def do_start(args)
        if @state.start
            send_error('already-started')
            return
        end

        if args.version != '1.0.0'
            send_error('unsupported-version')
            return
        end

        if args.protocol != 'yaml' and args.protocol != 'json'
            send_error('invalid-protocol-type')
            return
        end

        @protocol = args.protocol.to_sym
        @state.start = true

        send_start('protocol' => args.protocol)
        send_features
    end

    def do_starttls(args)
        if @state.tls
            send_stanza_error('starttls', 'already-encrypted')
            return
        end

        context = @diakofti.config.ssl_context
        socket  = OpenSSL::SSL::SSLSocket.new(@socket, context)

        begin
            socket.accept
            socket.sync_close = true
        rescue IO::WaitReadable
            IO.select([socket])
            retry
        rescue Exception => err
            $log.error "diakofti: TLS error: #{err}"
            send_starttls({ 'result' => 'failure' })
            $eventq.post(:extension_socket_dead, @socket)
        else
            @socket = socket
            @state.tls = true
            send_starttls({ 'result' => 'success' })
            send_features
        end
    end

    def do_authenticate(args)
        unless @state.start
            send_error('not-started')
            return
        end

        if @state.sasl
            send_stanza_error('authenticate', 'already-authenticated')
            return
        end

        unless args.mechanism == 'plain'
            send_stanza_error('authenticate', 'invalid-mechanism')
            return
        end

        data = args.payload.unpack('m')[0]
        authzid, authcid, passwd = data.split("\000")

        # XXX - make this actually work, use a dummy for now
        #account = Database::Account.resolve(authcid)

        account = OpenStruct.new
        account.login = 'rakaur@malkier.net'
        account.salt  = "9nqrtDNxbElevqbTLaEqIott1GR5dyfV+dBEwv7wJZ8vPGeqxAH4XP6Eyttk53CMEnmP3ZxeXe18WffxKIqnUl8uMNqvRtPNKFvbKF4AKAzrKg9psYWV1M41CNiYumXGmVbX5Dz5v75Ge0TKbd5A/15k4J4ZaZxc0ru/3+oLz8jF3LSKb6wxQieeSyWkDiarYtbKsh1Tm9eCm/1MLz+m7sTECXVmRfanxLfp+M6AC41WjyinKT9cGfZ1szltcLvOK6YhKaT/5RzR1ProM1E2RyWmmlnqe7RuCAFKSmGVLyF07GEniw3PSvjywl7XFu2z8V5dfe5fGwqtgBLeeRq8oA=="
        saltbytes = account.salt.unpack('m')[0]
        account.password = Digest::SHA2.hexdigest(saltbytes + 'MyL33tP455')

        passwd = Digest::SHA2.hexdigest(saltbytes + passwd)

        if not account or account.password != passwd
            send_stanza_error('authenticate', 'not-authorized')
            return
        else
            @state.sasl  = true
            @uuid = SecureRandom.uuid
            send_authenticate({ authcid => @uuid })
            send_features
        end
    end
end
