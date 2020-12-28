source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.2'

# Full-stack web application framework. (https://rubyonrails.org)
gem 'rails', '~> 6.1.0'

# The speed of a single-page web application without having to write any JavaScript. (https://github.com/hotwired/turbo-rails)
gem 'turbo-rails'

# Pg is the Ruby interface to the {PostgreSQL RDBMS}[http://www.postgresql.org/] (https://github.com/ged/ruby-pg)
gem 'pg', '~> 1.1'

# Puma is a simple, fast, threaded, and highly concurrent HTTP 1.1 server for Ruby/Rack applications (https://puma.io)
gem 'puma', '~> 5.0'

# Use webpack to manage app-like JavaScript modules in Rails (https://github.com/rails/webpacker)
gem 'webpacker', '~> 5.0'

# Boot large ruby/rails apps faster (https://github.com/Shopify/bootsnap)
gem 'bootsnap', '>= 1.4.4', require: false

# Timezone Data for TZInfo (https://tzinfo.github.io)
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Ruby library for InfluxDB 2. (https://github.com/influxdata/influxdb-client-ruby)
gem 'influxdb-client'

group :development, :test do
  # Ruby fast debugger - base + CLI (https://github.com/deivid-rodriguez/byebug)
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]

  # Autoload dotenv in Rails. (https://github.com/bkeepers/dotenv)
  gem 'dotenv-rails'

  # RSpec for Rails (https://github.com/rspec/rspec-rails)
  gem 'rspec-rails'

  # Automatic Ruby code style checking tool. (https://github.com/rubocop-hq/rubocop)
  gem 'rubocop', require: false

  # Automatic performance checking tool for Ruby code. (https://github.com/rubocop-hq/rubocop-performance)
  gem 'rubocop-performance', require: false

  # Automatic Rails code style checking tool. (https://github.com/rubocop-hq/rubocop-rails)
  gem 'rubocop-rails', require: false

  # Code style checking for RSpec files (https://github.com/rubocop-hq/rubocop-rspec)
  gem 'rubocop-rspec', require: false

  # Rails application preloader (https://github.com/rails/spring)
  gem 'spring'

  # rspec command for spring (https://github.com/jonleighton/spring-commands-rspec)
  gem 'spring-commands-rspec'
end

group :development do
  # A debugging tool for your Ruby on Rails applications. (https://github.com/rails/web-console)
  gem 'web-console', '>= 4.1.0'

  # Profiles loading speed for rack applications. (https://miniprofiler.com)
  gem 'rack-mini-profiler', '~> 2.0'

  # Listen to file modifications (https://github.com/guard/listen)
  gem 'listen', '~> 3.3'

  # Guard gem for RSpec (https://github.com/guard/guard-rspec)
  gem 'guard-rspec', require: false
end

group :test do
  # Code coverage for Ruby (https://github.com/simplecov-ruby/simplecov)
  gem 'simplecov', require: false
end

group :production do
  # Lock staging servers from search engines and prying eyes. (http://lockupgem.com)
  gem 'lockup'
end
