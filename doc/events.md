    kythera: services for IRC networks

    Copyright (c) 2011 Eric Will <rakaur@malkier.net>
    Rights to this code are documented in doc/license.txt

List of Events
==============

  * socket_readable
    * there is data on the socket ready to be read
    * params:
      * _none_

  * socket_writable
    * the socket is ready to be written to
    * params:
      * _none_

  * extension\_socket\_readable
    * there is data on the socket ready to be read
    * this is raised only for `Extension::Socket`
    * params:
      * the socket that is ready

  * extension\_socket\_writable
    * the socket is ready to be written to
    * this is raised only for `Extension::Socket`
    * params:
      * the socket that is ready

	* extension\_socket\_dead
	  * the socket is dead
	  * post this from your extension when you need your socket to be cleaned up
	  * params:
	    * the socket that is dead

  * connected
    * we are connected to the uplink
    * params:
      * _none_

  * disconnected
    * we have been disconnected from the uplink
    * params:
      * _none_

  * recvq_ready
    * the recvq has data ready to be parsed
    * params:
      * _none_
  
  * extension\_socket\_recvq\_ready
    * the recvq has data ready to be parsed
    * params:
      * the socket that is ready

  * start\_of\_burst
    * the service is starting to receive/send the connection burst
    * params:
      * A `Time` object representing the time the burst began

  * end\_of\_burst
    * the service has finished processing the connection burst
    * params:
      * A Float containing the time it took to process the burst

  * irc\_*
    * any command received by the uplink is posted as irc\_[command]
      * e.g.: PRIVMSG = irc_privmsg
      * e.g.: PING = irc_ping
      * params:
        * the origin, usually a server, nick!user@host, or protocol-specific ID
        * parv, an Array of space-tokenized paramaters after the IRC command

  * server_added
    * a server has joined the network
    * params:
      * a `Server` object

  * server_deleted
    * a server has left the network
    * params:
      * a `Server` object

  * user_added
    * a new `User` object has been created
    * params:
      * a `User` object

  * user_deleted
    * a user has left the network
    * params:
      * a `User` object

  * channel_added
    * a new `Channel` object has been created
    * params:
      * a `Channel` object

  * channel_deleted
    * all users have left a channel
    * params:
      * a `Channel` object

  * user\_joined\_channel
    * a user joined a channel
    * params:
      * a `User` object
      * a `Channel` object

  * user\_parted\_channel
    * a user parted a channel
    * params:
      * a `User` object
      * a `Channel` object

  * mode\_added\_on\_channel
    * a mode has been added on a channel
    * params:
      * mode symbol
      * mode params, or `nil`
      * a `Channel` object

  * mode\_deleted\_on\_channel
    * a mode has been deleted on a channel
    * params:
      * mode symbol
      * mode params, or `nil`
      * a `Channel` object

  * mode\_added\_to\_user
    * a mode has been added to a user
    * params:
      * mode symbol
      * a `User` object

  * mode\_deleted\_from\_user
    * a mode has been deleted from a user
    * params:
      * mode symbol
      * a `User` object

  * nickname_changed
    * a user has changed their nickname
    * params:
      * a `User` object, with the old nick
      * the new nick
