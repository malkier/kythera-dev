    kythera: services for IRC networks

    Copyright (c) 2011 Eric Will <rakaur@malkier.net>
    Rights to this code are documented in doc/license.md

kythera -- services for IRC networks
====================================

This application is free but copyrighted software; see `doc/license.md`.

To start the program, edit the configuration options in `bin/kythera` to
your satisfaction and run `./bin/kythera` at your terminal. Good luck!

More information and code repositories can be found on [GitHub][].

[github]: http://github.com/malkier/kythera/

--------------------------------------------------------------------------------

Kythera is a set of services for IRC networks. Kythera is extremely extensible
and is not limited to providing a specific set of services such as `NickServ`,
`ChanServ` vs. Undernet-style `X`, etc. You can configure the service to offer
pretty much anything you want. If it's not there, you can easily add support
for it if you know Ruby.

Ruby also brings us to my next point. Many people have told me that IRC services
must be implemented in C in order to have any hope of keeping up with medium-
to large-sized networks. I disagree. I actually spent a good amount of time
benchmarking various Ruby implementations to make sure this wasn't a silly
project. Having [previously implemented][shrike] services in C myself, I think
I'm quite qualified to judge the situation. In most cases, Ruby was reasonably
competitive with, and sometimes faster than traditional services written in C.

Most people running ircd are sysadmins that may know some dynamic languages
like Python and Ruby, but probably not static languages like C. It's my hope
that Kythera can compete on performance, and obliterate the competition on
ease-of-use and ease-of-hacking.

[shrike]: http://github.com/rakaur/shrike/

Command-Line Options
--------------------

Ruby supports the following command-line options to modify its runtime behavior:

    |------------+-------+--------------------|
    |   option   | short |       action       |
    |------------|-------|--------------------|
    | --debug    | -d    | debug mode         |
    | --help     | -h    | print usage info   |
    | --no-fork  | -n    | run in foreground  |
    | --quiet    | -q    | disable logging    |
    | --version  | -v    | print version info |
    |------------+-------+--------------------|

Ruby Support
------------

Kythera has been extensively tested with multiple Ruby implementations. Kythera
runs on all MRI / CRuby implementations, and will also run on Rubinius and
JRuby so long as you upgrade the bundled RubyGems version to at least 1.8.0.

    |----------------+-----------|
    | implementation |  version  |
    |----------------|-----------|
    | mri / cruby    | 1.8.7     |
    | mri / yarv     | 1.9.2     |
    | mri / yarv     | 1.9.3     |
    | rubinius       | 1.2, 2.0  |
    | jruby          | 1.6.5     |
    |----------------+-----------|

I had to find and report some bugs in JRuby to get Kythera to run on it, so
only very recent revisions work, and as of this writing, no official release
works out of the box. If you're using RVM, do this:

    $ rvm install jruby-head --branch jruby-1_6
    $ rvm use jruby-head
    $ gem install rubygems-update
    $ update_rubygems

If all of these work out, Kythera should run normally on JRuby excepting
background mode. JRuby does not provide the `Process.fork` call, and so it will
run in the foreground. You can background it using `nohup`:

    $ nohup bin/kythera -n &

This will background it and redirect all output to `nohup.out`.

Runtime Requirements
--------------------

This application has the following requirements:

    |------------+---------|
    | dependency | version |
    |------------|---------|
    | sqlite     | 3.7.6   |
    | rubygems   | 1.8.0   |
    |------------+---------|

This application requires the following RubyGems:

    |---------+---------|  |----------------------------------|
    | rubygem | version |  |          jruby rubygems          |
    |---------|---------|  |----------------------------------|
    | rake    | 0.9.2   |  | activerecord-jdbcsqlite3-adapter |
    | sequel  | 3.27.0  |  | jdbc-sqlite3                     |
    | sqlite3 | 1.3.4   |  | jruby-openssl                    |
    |---------+---------|  |----------------------------------|

Rake is required for testing and other automated tasks. Sequel and sqlite3 are
required for database management. These gems are widely available and should
not be a problem.

If you want to run the unit tests you'll also need to install riot:

    $ gem install riot
    $ rake test

IRCd Support
------------

Kythera is very modular and ships with support for many IRCds. In addition,
due to its extensible design, adding support to IRCds is a fairly easy task.

    |--------------+-------------+----------|
    |     ircd     |   version   | protocol |
    |--------------|-------------|----------+
    | charybdis    | 3.2.1       | ts6      |
    | InspIRCd     | 1.2.8       | inspircd |
    | ircd-ratbox  | 2.2.9       | ts6      |
    | ircu         | 2.10.12.14  | p10      |
    | UnrealIRCd   | 3.2.8.1     | unreal   |
    |--------------+-------------+----------|

Other TS6-based IRCds *might* work. For now, the TS6 module only provides support
for TS6-only networks. If you link a non-TS6 server, Kythera will ignore it.

Operating System Support
------------------------

Kythera will probably run anywhere that Ruby will run. Platforms like Windows
don't have the `fork` system call, and so it will not run in the background.
The application is written primarily on Mac OS X 10.7.2, and frequently tested
on FreeBSD 8.2 and Linux 2.6.37.2. If you have any trouble running the
application that you think is operating system related, please file
an [issue][] on [GitHub][].

Credits
-------

This application is completely original. I'm sure to receive patches from other
contributors from time to time, and this will be indicated in SCM commits.

    |----------------+----------+--------------------+-------------------------|
    |      role      | nickname |      realname      |      email address      |
    |----------------|----------|--------------------|-------------------------|
    | Lead Developer | rakaur   | Eric Will          | rakaur@malkier.net      |
    | Developer      | andrew   | Andrew Herbig      | goforit7arh@gmail.com   |
    | Developer      | sycobuny | Stephen Belcher    | sbelcher@gmail.com      |
    | Contributor    | xiphias  | Michael Rodriguez  | xiphias@khaydarin.net   |
    | Tester         | rintaun  | Matt Lanigan       | rintaun@projectxero.net |
    |----------------+----------+--------------------+-------------------------|

Contact and Support
-------------------

We're not promising any hard and fast support, but we'll try to do our best.
This is a hobby and we've enjoyed it, but we have real lives with real jobs and
real families. We cannot devote major quantities of time to this.

With that said, our email addresses are listed above. If you prefer real-time
you can try IRC. We run a small #kythera channel on freenode, and we also run
an extremely small privateish network at irc.malkier.net, #malkier.

If you have a bug feel free to drop by IRC or what have you, but we'll probably
just ask you to file an [issue][] on [GitHub][]. Please provide any output you
have, such as a backtrace. Please provide the steps we can take in order to
reproduce this problem, if possible. Feature requests are welcome and can be
filed in the same manner.

If you've read this far, congratulations. You are among the few elite people
that actually read documentation. Thank you.

[issue]: https://github.com/rakaur/kythera/issues
