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
