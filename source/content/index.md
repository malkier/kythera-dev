Kythera is a set of services for IRC networks. Kythera is extremely extensible
and is not limited to providing a specific set of services such as `NickServ`,
`ChanServ` vs. Undernet-style `X`, etc. You can configure the service to offer
pretty much anything you want. If it's not there, you can easily add support for
it if you know Ruby.

Ruby also brings us to my next point. Many people have told me that IRC services
must be implemented in C in order to have any hope of keeping up with medium-
to large-sized networks. I disagree. I actually spend a good amount of time
benchmarking various Ruby implementations to make sure this wasn't a silly
project. Having previously implemented services in C myself, I think
I'm quite qualified to judge the situation. In most cases, Ruby was reasonably
competitive with, and sometimes faster than traditional services written in C.

Most people running ircd are sysadmins that may know some dynamic languages
like Python and Ruby, but probably not static languages like C. It's my hope
that Kythera can compete on performance, and obliterate the competition on
ease-of-use and ease-of-hacking.

## Dependencies ##

This application has the following requirements:

  * ruby -- mri ~> 1.8; mri ~> 1.9; rbx ~> 1.2
  * sqlite ~> 3.0

This application requires the following RubyGems:

  * rake ~> 0.8
  * sequel ~> 3.23
  * sqlite3 ~> 1.3

Rake is required for testing and other automated tasks. Sequel and sqlite3 are
required for database management. These gems are widely available and should
not be a problem.

If you want to run the unit tests you'll also need `riot ~> 0.12` and run
`rake test` from your terminal. If you want to run the benchmarks you'll
need `benchmark_suite ~> 0.8.0` and probably `ffi ~> 1.0.9`.

## IRCds ##

Kythera can, in theory, support any IRCd. So long as a protocol module has
been written, your IRCd should work. Kythera ships with support for several
IRCds. These include:

  * ircd-ratbox (tested with 2.2.9)
  * charybdis (tested with 3.2.1)
  * UnrealIRCd (tested with 3.2.8.1)
  * InspIRCd (tested with 1.2.8)

Other TS6-based IRCds may work. For now, the TS6 module only provides support
for TS6-only networks. If you link a non-TS6 server, Kythera will ignore it.

## Authors ##

<table border='0'>
  <tr>
    <th>role</th>
    <th>nickname</th>
    <th>realname</th>
    <th>email</th>
  </tr>
  <tr>
    <td>Lead Developer</td>
    <td>rakaur</td>
    <td>Eric Will</td>
    <td>rakaur.at.malkier.dot.net</td>
  </tr>
  <tr>
    <td>Developer</td>
    <td>sycobuny</td>
    <td>Stephen Belcher</td>
    <td>sycobuny.at.malkier.dot.net</td>
  </tr>
  <tr>
    <td>Developer</td>
    <td>andrew</td>
    <td>Andrew Herbig</td>
    <td>goforit7arh.at.gmail.dot.com</td>
  </tr>
  <tr>
    <td>Contributor</td>
    <td>xiphias</td>
    <td>Michael Rodriguez</td>
    <td>xiphias.at.khaydarin.dot.net</td>
  </tr>
  <tr>
    <td>Tester</td>
    <td>rintaun</td>
    <td>Matt Lanigan</td>
    <td>rintaun.at.projectxero.dot.net</td>
  </tr>
</table>

## Download ##

You can download this project in either [zip][] or [tar][] formats.

You can also clone the project with [Git][] by running:

    $ git clone git://github.com/malkier/kythera

[zip]: http://github.com/malkier/kythera/zipball/master
[tar]: http://github.com/malkier/kythera/tarball/master
[Git]: http://git-scm.com

## License ##

Copyright (c) 2011, Eric Will
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

  * Neither the name of the author nor the names of its contributors may be
    used to endorse or promote products derived from this software without
    specific prior written permission.

  * Redistributions and derivative works may not be licensed under the
    GNU General Public License without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
