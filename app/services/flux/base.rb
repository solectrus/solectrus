class Flux::Base
  def client
    InfluxDB2::Client.new(
      "#{influx_schema}://#{influx_host}:#{influx_port}",
      influx_token,
      bucket: influx_bucket,
      org: influx_org,
      precision: InfluxDB2::WritePrecision::SECOND,
      use_ssl: influx_schema == 'https'
    )
  end

  private

  def influx_token
    ENV.fetch('INFLUX_TOKEN')
  end

  def influx_schema
    ENV.fetch('INFLUX_SCHEMA', 'http')
  end

  def influx_host
    ENV.fetch('INFLUX_HOST')
  end

  def influx_port
    ENV.fetch('INFLUX_PORT', 8086)
  end

  def influx_bucket
    ENV.fetch('INFLUX_BUCKET')
  end

  def influx_org
    ENV.fetch('INFLUX_ORG')
  end
end
