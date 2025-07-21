require 'simplecov_json_formatter'

SimpleCov.start 'rails' do
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
