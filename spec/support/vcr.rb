VCR.configure do |config|
  config.hook_into :webmock
  config.cassette_library_dir = 'spec/support/cassettes'
  config.configure_rspec_metadata!

  sensitive_environment_variables = %w[
    INFLUX_HOST
    INFLUX_TOKEN
    INFLUX_ORG
    INFLUX_BUCKET
  ]
  sensitive_environment_variables.each do |key_name|
    config.filter_sensitive_data("<#{key_name}>") { ENV.fetch(key_name) }
  end

  # Let's you set default VCR mode with VCR=new_episodes for re-recording
  # episodes. :once is VCR default
  record_mode = ENV['VCR'] ? ENV['VCR'].to_sym : :once
  config.default_cassette_options = { record: record_mode, allow_playback_repeats: true, serialize_with: :psych }

  hosts_to_ignore = [
    'localhost', '127.0.0.1', '0.0.0.0' # rubocop:disable Style/IpAddresses
  ]

  # Allow gem "webdrivers" to download drivers
  hosts_to_ignore += Webdrivers::Common.subclasses.map { |driver| URI(driver.base_url).host }

  config.ignore_hosts(*hosts_to_ignore)
end
