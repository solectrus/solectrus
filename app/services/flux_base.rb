class FluxBase
  def initialize(*fields)
    @fields = fields
  end
  attr_reader :fields

  private

  def from_bucket
    "from(bucket: \"#{influx_bucket}\")"
  end

  def fields_filter
    filter = fields.map do |field|
      "r[\"_field\"] == \"#{field}\""
    end

    "filter(fn: (r) => #{filter.join(' or ')})"
  end

  def measurement_filter
    "filter(fn: (r) => r[\"_measurement\"] == \"#{measurement}\")"
  end

  def range(start:, stop: nil)
    if stop
      "range(start: #{start}, stop: #{stop})"
    else
      "range(start: #{start})"
    end
  end

  def query(string)
    client.create_query_api.query(query: string, org: influx_org)
  end

  def client
    InfluxDB2::Client.new(
      "#{influx_schema}://#{influx_host}:#{influx_port}",
      influx_token,
      precision: InfluxDB2::WritePrecision::SECOND,
      use_ssl: influx_schema == 'https'
    )
  end

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

  def measurement
    'SENEC'
  end
end
