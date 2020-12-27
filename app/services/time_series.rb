class TimeSeries
  def initialize(field)
    @field = field
  end

  def last24h
    query <<-QUERY
      from(bucket: "#{influx_bucket}")
      |> range(start: -24h)
      |> filter(fn: (r) => r["_measurement"] == "#{measurement}")
      |> filter(fn: (r) => r["_field"] == "#{@field}")
      |> aggregateWindow(
           every: 1h,
           fn: (tables=<-, column) =>
             tables
               |> integral(unit: 1h)
               |> map(fn: (r) => ({ r with _value: r._value / 1000.0 }))
         )
      |> sum()
    QUERY
  end

  private

  def query(string)
    tables = client.create_query_api.query(query: string, org: influx_org)
    tables.first.second.records.first.values['_value']
  end

  def client
    @client ||= begin
      InfluxDB2::Client.new(
        influx_host,
        influx_token,
        precision: InfluxDB2::WritePrecision::SECOND
      )
    end
  end

  def influx_token
    ENV.fetch('INFLUX_TOKEN')
  end

  def influx_host
    ENV.fetch('INFLUX_HOST')
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
