SimpleCov.start 'rails' do
  add_group 'Services', 'app/services'
  add_group 'Components', 'app/components'
  add_group 'Middleware', 'app/middleware'

  add_filter 'app/jobs/application_job.rb'
  add_filter 'app/channels/application_cable/connection.rb'
  add_filter 'app/channels/application_cable/channel.rb'
  add_filter 'app/models/application_record.rb'
end
