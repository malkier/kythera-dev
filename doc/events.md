    kythera: services for IRC networks

    Copyright (c) 2011 Eric Will <rakaur@malkier.net>
    Rights to this code are documented in doc/license.md

List of Events
==============

Kythera has an event system for edge cases where it does not provide some other
high level API to accomplish your task. This is a list of those events.

Exit Event
----------

There is a somewhat special event, called `:exit`. It is special in the sense
that the event queue runner looks specifically for it and runs every other
event in the queue first, then runs the exit handlers, and then asks the main
loop to exit. The exit event exists to allow you to clean things up (close
files, save things, etc.). When the main loop is asked to exit, it makes a note
of this request and goes ahead and runs through the IO loop one more time in
order for any socket-dependent events added by exit handlers to run (such as
sending data to the IRC uplink), and then will exit gracefully. This "one more
loop" behavior is a special case, and is your last chance to run something.

If you're going to handle this event, you should stop to think whether you
should be using `EventQueue#handle` or `EventQueue#persistently_handle`. The
former gets wiped out when the uplink gets disconnected, and the latter never
gets wiped out. If you're a service, you're instantiated every time the uplink
reconnects, so if you add the exit handler in your initialize method, then
using the former is just fine. If you're an extension (or something else not
tied to the main loop), you want to use the latter.

You're also free to post the :exit event, which will trigger the above series
of events. Of course, you should only do this for a very good reason (usually,
user input that has asked the application to shut down). If you post it, any
params you post with it should respond to `to_s` and in general, there should
only be one param--a `String`--that describes why we're exiting.

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
    | nickname_changed       | User, old nick         | user /nick'd          |
    |------------------------+------------------------+-----------------------|

Server Events
--------------

    |----------------+------------+-------------------|
    |   event name   | parameters |    posted when    |
    |----------------|------------|-------------------|
    | server_added   | Server     | server connected  |
    | server_deleted | Server     | server departed   |
    |----------------+------------+-------------------|
