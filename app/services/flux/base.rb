class Flux::Base
  def client
    InfluxDB2::Client.new(
      influx_url,
      influx_token,
      bucket: influx_bucket,
      org: influx_org,
      precision: InfluxDB2::WritePrecision::SECOND,
      use_ssl: influx_schema == 'https',
      read_timeout: 30,
    )
  end

  private

  def influx_url
    "#{influx_schema}://#{influx_host}:#{influx_port}"
  end

  def influx_schema
    Rails.configuration.x.influx.schema
  end

  def influx_host
    Rails.configuration.x.influx.host
  end

  def influx_port
    Rails.configuration.x.influx.port
  end

  def influx_token
    Rails.configuration.x.influx.token
  end

  def influx_bucket
    Rails.configuration.x.influx.bucket
  end

  def influx_org
    Rails.configuration.x.influx.org
  end
end
