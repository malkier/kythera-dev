    kythera: services for IRC networks

    Copyright (c) 2011 Eric Will <rakaur@malkier.net>
    Rights to this code are documented in doc/license.txt

kythera -- services for IRC networks
==========================================

This application is free but copyrighted software; see doc/license.txt.

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

## Ruby Support ##

Kythera has been extensively tested with multiple Ruby implementations. Kythera
runs out-of-the-box on the following implementations:

  * ruby-1.8.7
  * ruby-1.9.2
  * ruby-1.9.3
  * ree

Kythera will also run on Rubinius and JRuby, but you'll have to upgrade the
bundled RubyGems version to at least version 1.8.0:

  * jruby-1.6.4 (at least 2011-09-15)
  * rubinius-1.2 (2.0.0 preferred)

I had to find and report some bugs in JRuby to get Kythera to run on it, so
only very recent revisions work, and as of this writing, no official release
works out of the box. If you're using RVM, do this:

    $ rvm install jruby-head --branch jruby-1_6
    $ rvm use jruby-head
    $ gem install rubygems-update
    $ update_rubygems

If all of these work out, Kythera should run just fine on JRuby.

## Runtime requirements ##

This application has the following requirements:

  * ruby
    * mri ~> 1.8
    * mri ~> 1.9.2
    * rbx ~> 1.2
    * jruby ~> 1.6.4 (as of 2011-09-15)

  * sqlite ~> 3.0
  * rubygems ~> 1.8.0

This application requires the following RubyGems:

  * rake ~> 0.8
  * sequel ~> 3.23
  * sqlite3 ~> 1.3

Rake is required for testing and other automated tasks. Sequel and sqlite3 are
required for database management. These gems are widely available and should
not be a problem.

If you want to use JRuby, you'll also need the following gems:

  * activerecord-jdbcsqlite3-adapter
  * jdbc-sqlite3
  * jruby-openssl

If you want to run the unit tests you'll also need `riot ~> 0.12` and run
`rake test` from your terminal.

## IRCd support ##

Kythera can, in theory, support any IRCd. So long as a protocol module has
been written, your IRCd should work. Kythera ships with support for several
IRCds. These include:

|-------------+------------+----------|
| ircd        | version    | protocol |
|-------------|------------|----------+
| charybdis   | 3.2.1      | ts6      |
| InspIRCd    | 1.2.8      | inspircd |
| ircd-ratbox | 2.2.9      | ts6      |
| ircu        | 2.10.12.14 | p10      |
| UnrealIRCd  | 3.2.8.1    | unreal   |
|-------------+------------+----------|

Other TS6-based IRCds *might* work. For now, the TS6 module only provides support
for TS6-only networks. If you link a non-TS6 server, Kythera will ignore it.

## Credits ##

This application is completely original. I'm sure to receive patches from other
contributors from time to time, and this will be indicated in SCM commits.

|----------------+----------+-------------------+-------------------------|
| role           | nickname | realname          | email                   |
|----------------|----------|-------------------|-------------------------|
| Lead Developer | rakaur   | Eric Will         | rakaur@malkier.net      |
| Developer      | andrew   | Andrew Herbig     | goforit7arh@gmail.com   |
| Developer      | sycobuny | Stephen Belcher   | sbelcher@gmail.com      |
| Contributor    | xiphias  | Michael Rodriguez | xiphias@khaydarin.net   |
| Tester         | rintaun  | Matt Lanigan      | rintaun@projectxero.net |
|----------------+----------+-------------------+-------------------------|
    
## Contact and Support ##

I'm not promising any hard and fast support, but I'll try to do my best. This
is a hobby and I've enjoyed it, but I have a real life with a real job and
a real family. I cannot devote major quantities of time to this.

With that said, my email addresses is all over the place. If you prefer
real-time you can try to catch me on IRC at `irc.malkier.net` in `#malkier`.
I'm also available on XMPP at `rakaur@malkier.net`.

If you have a bug feel free to drop by IRC or what have you, but I'm probably
just going to ask you to file an [issue][] on [GitHub][]. Please provide any
output you have, such as a backtrace. Please provide the steps anyone can take
to reproduce this problem. Feature requests are welcome and can be filed in
the same manner.

If you've read this far, congratulations. You are among the few elite people
that actually read documentation. Thank you.

[issue]: https://github.com/rakaur/kythera/issues
