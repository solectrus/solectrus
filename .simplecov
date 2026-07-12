require 'simplecov_json_formatter'

# Configuration only; coverage tracking is started explicitly via
# `SimpleCov.start 'rails'` in spec/rails_helper.rb (SimpleCov 1.0+).
# The collate task supplies its own formatter, so skip this config there.
return if ENV['SIMPLECOV_COLLATE_ONLY']

SimpleCov.configure do
  # Enable merging of coverage results from multiple test runs
  merging true
  merge_timeout 3600 # 1 hour

  # Set command name from ENV or use default
  command_name ENV.fetch('COVERAGE_NAME', 'RSpec')

  formatter SimpleCov::Formatter::MultiFormatter.new(
              [
                SimpleCov::Formatter::JSONFormatter,
                SimpleCov::Formatter::HTMLFormatter,
              ],
            )

  group 'Services', 'app/services'
  group 'Components', 'app/components'
  group 'Middleware', 'app/middleware'

  skip 'app/jobs/application_job.rb'
  skip 'app/channels/application_cable/connection.rb'
  skip 'app/channels/application_cable/channel.rb'
  skip 'app/models/application_record.rb'
end
