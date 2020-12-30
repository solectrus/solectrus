class TimeSeries
  def initialize(*fields)
    @fields = fields
  end

  def last24h
    result = query <<-QUERY
      #{from_bucket}
      |> #{range_since('24h')}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> aggregateWindow(
           every: 1h,
           fn: (tables=<-, column) =>
             tables
               |> integral(unit: 1h)
               |> map(fn: (r) => ({ r with _value: r._value / 1000.0 }))
         )
      |> sum()
    QUERY

    result.values.each_with_object({}) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_stop']
    end
  end

  private

  def from_bucket
    "from(bucket: \"#{influx_bucket}\")"
  end

  def fields_filter
    filter = @fields.map do |field|
      "r[\"_field\"] == \"#{field}\""
    end

    "filter(fn: (r) => #{filter.join(' or ')})"
  end

  def measurement_filter
    "filter(fn: (r) => r[\"_measurement\"] == \"#{measurement}\")"
  end

  def range_since(value)
    "range(start: -#{value})"
  end

  def query(string)
    client.create_query_api.query(query: string, org: influx_org)
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
