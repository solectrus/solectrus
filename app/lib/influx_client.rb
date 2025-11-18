class InfluxClient
  config = Rails.configuration.x.influx
  @client =
    InfluxDB2::Client.new(
      "#{config.schema}://#{config.host}:#{config.port}",
      config.token,
      bucket: config.bucket,
      org: config.org,
      precision: InfluxDB2::WritePrecision::SECOND,
      use_ssl: config.schema == 'https',
      read_timeout: 30,
    )

  # Create APIs once at initialization for thread-safety and performance
  @query_api = @client.create_query_api
  @write_api = @client.create_write_api
  @delete_api = @client.create_delete_api

  class << self
    attr_reader :client, :query_api, :write_api, :delete_api

    delegate :ping, :health, to: :client
  end
end
