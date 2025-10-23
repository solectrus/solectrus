require 'simplecov_json_formatter'

SimpleCov.start 'rails' do
  # Enable merging of coverage results from multiple test runs
  use_merging true
  merge_timeout 3600 # 1 hour

  # Set command name from ENV or use default
  command_name ENV.fetch('COVERAGE_NAME', 'RSpec')

  formatter SimpleCov::Formatter::MultiFormatter.new(
              [
                SimpleCov::Formatter::JSONFormatter,
                SimpleCov::Formatter::HTMLFormatter,
              ],
            )

  add_group 'Services', 'app/services'
  add_group 'Components', 'app/components'
  add_group 'Middleware', 'app/middleware'

  add_filter 'app/jobs/application_job.rb'
  add_filter 'app/channels/application_cable/connection.rb'
  add_filter 'app/channels/application_cable/channel.rb'
  add_filter 'app/models/application_record.rb'
end
