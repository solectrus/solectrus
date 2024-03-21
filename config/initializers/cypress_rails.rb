if ENV['RAILS_ENV'] == 'test'
  # Enable code coverage
  require 'simplecov'
end

return unless Rails.env.test?
return unless Rails.configuration.x.influx.host == 'localhost'

Rails.application.load_tasks unless defined?(Rake::Task)

# Load the support files
require 'active_support/testing/time_helpers'
Dir[Rails.root.join('spec', 'cypress', 'support', '**', '*.rb')].each do |f|
  require f
end

CypressRails.hooks.before_server_start do
  # Called once, before either the transaction or the server is started

  # Write coverage data to separate namespace so it can be merged with the RSpec coverage
  SimpleCov.command_name 'Cypress'

  # Time traveling
  include ActiveSupport::Testing::TimeHelpers
  travel_to Time.zone.local(2022, 6, 21, 12, 0, 0)

  # Seed database
  Rake::Task['db:seed'].invoke

  # Seed InfluxDB
  include CypressRails::InfluxDB
  influx_seed
end

CypressRails.hooks.after_server_start do
  # Called once, after the server has booted

  # Stub the version check so we don't have to hit the network
  UpdateCheck.class_eval do
    def latest
      { 'registration_status' => 'registered', 'version' => '1.0.0' }
    end
  end
end

CypressRails.hooks.after_transaction_start do
  # Called after the transaction is started (at launch and after each reset)
end

CypressRails.hooks.after_state_reset do
  # Triggered after `/cypress_rails_reset_state` is called
end

CypressRails.hooks.before_server_stop do
  # Called once, at_exit

  # Purge InfluxDB data
  influx_purge

  # Purge and reload the test database so we don't leave our fixtures in there
  Rake::Task['db:test:prepare'].invoke

  # Stop time traveling
  travel_back
end
