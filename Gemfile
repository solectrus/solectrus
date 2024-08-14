source 'https://rubygems.org'

ruby file: '.ruby-version'

# URI is a module providing classes to handle Uniform Resource Identifiers (https://github.com/ruby/uri)
gem 'uri', '>= 0.12.2'

# Full-stack web application framework. (https://rubyonrails.org)
gem 'rails', '~> 7.2.0'

# Use Vite in Rails and bring joy to your JavaScript experience (https://github.com/ElMassimo/vite_ruby)
gem 'vite_rails'

# The speed of a single-page web application without having to write any JavaScript. (https://github.com/hotwired/turbo-rails)
gem 'turbo-rails'

# A modest JavaScript framework for the HTML you already have. (https://stimulus.hotwired.dev)
gem 'stimulus-rails'

# Pg is the Ruby interface to the PostgreSQL RDBMS (https://github.com/ged/ruby-pg)
gem 'pg', '~> 1.1'

# Puma is a simple, fast, threaded, and highly parallel HTTP 1.1 server for Ruby/Rack applications (https://puma.io)
gem 'puma', '>= 5.0'

# A Ruby client library for Redis (https://github.com/redis/redis-rb)
gem 'redis', '>= 4.0.1'

# Boot large ruby/rails apps faster (https://github.com/Shopify/bootsnap)
gem 'bootsnap', require: false

# The best solution for store global settings in Rails applications. (https://github.com/huacnlee/rails-settings-cached)
gem 'rails-settings-cached'

# Slim templates generator for Rails (https://github.com/slim-template/slim-rails)
gem 'slim-rails'

# Middleware for enabling Cross-Origin Resource Sharing in Rack apps (https://github.com/cyu/rack-cors)
gem 'rack-cors', require: 'rack/cors'

# Block & throttle abusive requests (https://github.com/rack/rack-attack)
gem 'rack-attack'

# Brotli compression for Rack responses (http://github.com/marcotc/rack-brotli/)
gem 'rack-brotli'

# Tame Rails' multi-line logging into a single line per request (https://github.com/roidrage/lograge)
gem 'lograge'

# Ruby library for InfluxDB 2. (https://github.com/influxdata/influxdb-client-ruby)
gem 'influxdb-client', '>= 2.9.0'

# A framework for building reusable, testable & encapsulated view components in Ruby on Rails. (https://viewcomponent.org)
gem 'view_component'

# Find out which locale the user preferes by reading the languages they specified in their browser (https://github.com/iain/http_accept_language)
gem 'http_accept_language'

# Ruby on Rails applications monitoring (https://www.rorvswild.com)
gem 'rorvswild'

# CSV Reading and Writing (https://github.com/ruby/csv)
gem 'csv'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  # gem 'debug', platforms: %i[ mri windows ], require: 'debug/prelude'

  # Loads environment variables from `.env`. (https://github.com/bkeepers/dotenv)
  gem 'dotenv'

  # RSpec for Rails (https://github.com/rspec/rspec-rails)
  gem 'rspec-rails'

  # rspec-collection_matchers-1.2.1 (https://github.com/rspec/rspec-collection_matchers)
  gem 'rspec-collection_matchers', require: false

  # Automatic Ruby code style checking tool. (https://github.com/rubocop/rubocop)
  gem 'rubocop', require: false

  # Code style checking for Capybara test files (https://github.com/rubocop/rubocop-capybara)
  gem 'rubocop-capybara', require: false

  # Automatic performance checking tool for Ruby code. (https://github.com/rubocop/rubocop-performance)
  gem 'rubocop-performance', require: false

  # Automatic Rails code style checking tool. (https://github.com/rubocop/rubocop-rails)
  gem 'rubocop-rails', require: false

  # Code style checking for RSpec files (https://github.com/rubocop/rubocop-rspec)
  gem 'rubocop-rspec', require: false

  # Code style checking for RSpec Rails files (https://github.com/rubocop/rubocop-rspec_rails)
  gem 'rubocop-rspec_rails', require: false

  # Thread-safety checks via static analysis (https://github.com/rubocop/rubocop-thread_safety)
  gem 'rubocop-thread_safety', require: false

  # Slim template linting tool (https://github.com/sds/slim-lint)
  gem 'slim_lint'

  # Helps you write Cypress tests of your Rails app (https://github.com/testdouble/cypress-rails)
  # Fork for Rails 7.2 compatibility.
  # Change this line when https://github.com/testdouble/cypress-rails/pull/165 is merged.
  gem 'cypress-rails', github: 'ledermann/cypress-rails', branch: 'rails-7-2'
end

group :development do
  # Security vulnerability scanner for Ruby on Rails. (https://brakemanscanner.org)
  gem 'brakeman', require: false

  # A debugging tool for your Ruby on Rails applications. (https://github.com/rails/web-console)
  gem 'web-console'

  # Guard gem for RSpec (https://github.com/guard/guard-rspec)
  gem 'guard-rspec', require: false

  # Rails application preloader (https://github.com/rails/spring)
  gem 'spring'

  # rspec command for spring (https://github.com/jonleighton/spring-commands-rspec)
  gem 'spring-commands-rspec', require: false

  # A native development UI for ViewComponent (https://github.com/lookbook-hq/lookbook)
  gem 'lookbook'

  # A gem for generating annotations for Rails projects. (https://github.com/drwl/annotaterb)
  gem 'annotaterb'

  # Pretty print Ruby objects with proper indentation and colors (https://github.com/amazing-print/amazing_print)
  gem 'amazing_print'
end

group :test do
  # Capybara aims to simplify the process of integration testing Rack applications, such as Rails, Sinatra or Merb (https://github.com/teamcapybara/capybara)
  gem 'capybara', '>= 3.26'

  # Code coverage for Ruby (https://github.com/simplecov-ruby/simplecov)
  gem 'simplecov', require: false

  # Simple one-liner tests for common Rails functionality (https://matchers.shoulda.io/)
  gem 'shoulda-matchers'

  # Record your test suite's HTTP interactions and replay them during future test runs for fast, deterministic, accurate tests. (https://benoittgt.github.io/vcr)
  gem 'vcr'

  # Library for stubbing HTTP requests in Ruby. (https://github.com/bblimke/webmock)
  gem 'webmock'
end

group :production do
  # Lock staging servers from search engines and prying eyes. (http://lockup.interdiscipline.com)
  # Fork for Rails 7.2 compatibility.
  # Change this line when https://github.com/interdiscipline/lockup/pull/75 is merged.
  gem 'lockup', github: 'ledermann/lockup', branch: 'rails-7-2'

  # Error reports you can be happy about. (https://www.honeybadger.io/for/ruby/)
  gem 'honeybadger', require: ENV.key?('HONEYBADGER_API_KEY')
end
