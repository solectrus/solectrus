# Configuration only; coverage tracking is started explicitly via
# `SimpleCov.start 'rails'` in spec/rails_helper.rb (SimpleCov 1.0+).
# Loaded on `require "simplecov"`, so `rake coverage:merge` picks up the
# same groups and filters for the merged report.
SimpleCov.configure do
  # Enable merging of coverage results from multiple test runs
  merging true
  merge_timeout 3600 # 1 hour

  # Set command name from ENV or use default
  command_name ENV.fetch('COVERAGE_NAME', 'RSpec')

  group 'Services', 'app/services'
  group 'Policies', 'app/policies'
  group 'Components', 'app/components'
  group 'Middleware', 'app/middleware'

  skip 'app/jobs/application_job.rb'
  skip 'app/channels/application_cable/connection.rb'
  skip 'app/channels/application_cable/channel.rb'
  skip 'app/models/application_record.rb'
end
