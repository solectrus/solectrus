source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

# Full-stack web application framework. (https://rubyonrails.org)
gem 'rails', '~> 7.0.3'

# Sprockets Rails integration (https://github.com/rails/sprockets-rails)
gem 'sprockets-rails'

# Adds multiple exporters to Sprockets (https://github.com/hansottowirtz/sprockets-exporters_pack)
gem 'sprockets-exporters_pack'

# The speed of a single-page web application without having to write any JavaScript. (https://github.com/hotwired/turbo-rails)
gem 'turbo-rails'

# A modest JavaScript framework for the HTML you already have. (https://stimulus.hotwired.dev)
gem 'stimulus-rails'

# Bundle and transpile JavaScript in Rails with esbuild, rollup.js, or Webpack. (https://github.com/rails/jsbundling-rails)
gem 'jsbundling-rails'

# Bundle and process CSS with Tailwind, Bootstrap, PostCSS, Sass in Rails via Node.js. (https://github.com/rails/cssbundling-rails)
gem 'cssbundling-rails'

# Pg is the Ruby interface to the PostgreSQL RDBMS (https://github.com/ged/ruby-pg)
gem 'pg', '~> 1.1'

# Puma is a simple, fast, threaded, and highly parallel HTTP 1.1 server for Ruby/Rack applications (https://puma.io)
gem 'puma', '~> 5.0'

# A Ruby client library for Redis (https://github.com/redis/redis-rb)
gem 'redis'

# Boot large ruby/rails apps faster (https://github.com/Shopify/bootsnap)
gem 'bootsnap', require: false

# Timezone Data for TZInfo (https://tzinfo.github.io)
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Slim templates generator for Rails (https://github.com/slim-template/slim-rails)
gem 'slim-rails'

# Tame Rails' multi-line logging into a single line per request (https://github.com/roidrage/lograge)
gem 'lograge'

# Ruby library for InfluxDB 2. (https://github.com/influxdata/influxdb-client-ruby)
gem 'influxdb-client'

# View components for Rails (https://github.com/github/view_component)
gem 'view_component'

# Collection of SEO helpers for Ruby on Rails. (https://github.com/kpumuk/meta-tags)
gem 'meta-tags'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  # gem 'debug', platforms: %i[ mri mingw x64_mingw ]

  # Autoload dotenv in Rails. (https://github.com/bkeepers/dotenv)
  gem 'dotenv-rails'

  # RSpec for Rails (https://github.com/rspec/rspec-rails)
  gem 'rspec-rails'

  # rspec-collection_matchers-1.2.0 (https://github.com/rspec/rspec-collection_matchers)
  gem 'rspec-collection_matchers'

  # Automatic Ruby code style checking tool. (https://github.com/rubocop/rubocop)
  gem 'rubocop', require: false

  # Automatic performance checking tool for Ruby code. (https://github.com/rubocop/rubocop-performance)
  gem 'rubocop-performance', require: false

  # Automatic Rails code style checking tool. (https://github.com/rubocop/rubocop-rails)
  gem 'rubocop-rails', require: false

  # Code style checking for RSpec files (https://github.com/rubocop/rubocop-rspec)
  gem 'rubocop-rspec', require: false

  # Slim template linting tool (https://github.com/sds/slim-lint)
  gem 'slim_lint'
end

group :development do
  # A debugging tool for your Ruby on Rails applications. (https://github.com/rails/web-console)
  gem 'web-console'

  # Profiles loading speed for rack applications. (https://miniprofiler.com)
  # gem 'rack-mini-profiler'

  # Guard gem for RSpec (https://github.com/guard/guard-rspec)
  gem 'guard-rspec', require: false

  # Rails application preloader (https://github.com/rails/spring)
  gem 'spring'

  # rspec command for spring (https://github.com/jonleighton/spring-commands-rspec)
  gem 'spring-commands-rspec'
end

group :test do
  # Capybara aims to simplify the process of integration testing Rack applications, such as Rails, Sinatra or Merb (https://github.com/teamcapybara/capybara)
  gem 'capybara', '>= 3.26'

  # Automatically create snapshots when Cucumber steps fail with Capybara and Rails (http://github.com/mattheworiordan/capybara-screenshot)
  gem 'capybara-screenshot'

  # Selenium is a browser automation tool for automated testing of webapps and more (https://selenium.dev)
  gem 'selenium-webdriver'

  # Easy download and use of browser drivers. (https://github.com/titusfortner/webdrivers)
  gem 'webdrivers'

  # Code coverage for Ruby (https://github.com/simplecov-ruby/simplecov)
  gem 'simplecov', require: false
end

group :production do
  # Lock staging servers from search engines and prying eyes. (http://lockup.interdiscipline.com)
  gem 'lockup'

  # Error reports you can be happy about. (https://github.com/honeybadger-io/honeybadger-ruby)
  gem 'honeybadger'
end
