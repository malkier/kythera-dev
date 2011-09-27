source :rubygems

gem 'rake'
gem 'sequel',  '~> 3.23'

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter', :require => false
  gem 'jdbc-sqlite3',                     :require => false
  gem 'jruby-openssl'
end

platforms :ruby do
  gem 'sqlite3', '~> 1.3'
end

platforms :rbx do
  gem 'rdoc'
end

group :test do
  gem 'riot'
end
