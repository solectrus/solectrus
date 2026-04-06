class Influx
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

  # Create query API once at initialization for thread-safety and performance
  @query_api = @client.create_query_api

  @version =
    begin
      version = Gem::Version.new(@client.health.version.delete_prefix('v'))

      if version < Gem::Version.new('2.8')
        Rails.logger.warn(
          "InfluxDB version #{version} detected. Consider upgrading to 2.8 for best compatibility and performance.",
        )
      end

      version
    rescue StandardError => e
      Rails.logger.error("Error determining InfluxDB version: #{e.message}")
      Gem::Version.new('0')
    end

  class << self
    attr_reader :client, :query_api, :version

    delegate :ping, :health, to: :client
  end
end
