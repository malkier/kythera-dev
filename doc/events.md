    kythera: services for IRC networks

    Copyright (c) 2011 Eric Will <rakaur@malkier.net>
    Rights to this code are documented in doc/license.md

List of Events
==============

Kythera has an event system for edge cases where it does not provide some other
high level API to accomplish your task. This is a list of those events.

IRC Command Events
-------------------

In addition to the events listed in the tables below, an event is posted for
every single command received from the server. These events are named with an
"irc\_" prefix, followed by the name of the command (e.g.: irc_join). Two
parameters are provided, named "origin" and "parv." The "origin" parameter is a
String containing the server name, nick!user@host, or protocol-specific ID of
the entity that sent the command. The "parv" parameter is an Array consisting
of space-tokenized parameters to the command. For example:

    :rakaur!rakaur@malkier.net PRIVMSG #malkier :hello world

Will result in:

    origin = "rakaur!rakaur@malkier.net"
    parv   = ["#malkier", "hello world"]

This fairly low-level event system allows you to hook into any IRC command
rather than be limited to the ones below, but at the cost of having to do some
of your own parsing. For example, an "irc\_mode" event is going to give you
the raw mode string (e.g.: "+knt key") rather than a parsed-out version. This
is the cost of doing business, I'm afraid.

The rest of the higher-level events are documented below.

Extension Events
----------------

    |----------------------------+------------+-----------------------|
    |         event name         | parameters |      posted when      |
    |----------------------------|------------|-----------------------|
    | extension_socket_dead      | TCPSocket  | extension socket died |
    | extension_socket_readable  | TCPSocket  | socket ready to read  |
    | extension_socket_parsable  | TCPSocket  | socket ready to parse |
    | extension_socket_writable  | TCPSocket  | socket ready to write |
    |----------------------------+------------+-----------------------|

Network Events
--------------

    |----------------------------+------------+-----------------------|
    |         event name         | parameters |      posted when      |
    |----------------------------|------------|-----------------------|
    | connected                  | none       | connected to uplink   |
    | end_of_burst               | burst time | IRC burst is finished |
    | extension_socket_dead      | TCPSocket  | extension socket died |
    | extension_socket_readable  | TCPSocket  | socket ready to read  |
    | extension_socket_parsable  | TCPSocket  | socket ready to parse |
    | extension_socket_writable  | TCPSocket  | socket ready to write |
    | start_of_burst             | start time | IRC burst has started |
    | uplink_parsable            | none       | uplink ready to parse |
    | uplink_readable            | none       | uplink ready to read  |
    | uplink_writable            | none       | uplink ready to write |
    |----------------------------+------------+-----------------------|

Channel Events
--------------

    |-------------------------+------------------------+-----------------------|
    |       event name        |       parameters       |      posted when      |
    |-------------------------|------------------------|-----------------------|
    | channel_added           | Channel                | Channel created       |
    | channel_deleted         | Channel                | Channel abandoned     |
    | user_joined_channel     | User, Channel          | User joined a Channel |
    | user_parted_channel     | User, Channel          | User parted a Channel |
    | mode_added_on_channel   | Symbol, param, Channel | set +mode on Channel  |
    | mode_deleted_on_channel | Symbol, param, Channel | set -mode on Channel  |
    |-------------------------+------------------------+-----------------------|

User Events
-----------

    |------------------------+------------------------+-----------------------|
    |       event name       |       parameters       |      posted when      |
    |------------------------|------------------------|-----------------------|
    | user_added             | User                   | user connected        |
    | user_deleted           | User                   | user departed         |
    | user_joined_channel    | User, Channel          | User joined a Channel |
    | user_parted_channel    | User, Channel          | User parted a Channel |
    | mode_added_to_user     | Symbol, param, User    | set +mode on User     |
    | mode_deleted_from_user | Symbol, param, User    | set -mode on User     |
    | nickname_changed       | User, new nick         | user /nick'd          |
    |------------------------+------------------------+-----------------------|

Server Events
--------------

    |----------------+------------+-------------------|
    |   event name   | parameters |    posted when    |
    |----------------|------------|-------------------|
    | server_added   | Server     | server connected  |
    | server_deleted | Server     | server departed   |
    |----------------+------------+-------------------|
