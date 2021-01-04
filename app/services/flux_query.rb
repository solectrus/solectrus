class FluxQuery
  def initialize(*fields)
    @fields = fields
  end

  def current
    last('-1h')
  end

  def day
    range('-24h')
  end

  def week
    range('-7d')
  end

  def month
    range('-30d')
  end

  def year
    range('-365d')
  end

  def all
    range('0')
  end

  private

  def empty_hash
    result = {}
    @fields.each do |field|
      result[field] = nil
    end
    result[:time] = nil
    result
  end

  def last(timeframe)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range_since(timeframe)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> last()
    QUERY

    result.values.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_time']
    end
  end

  def range(timeframe)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range_since(timeframe)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> sum()
    QUERY

    result.values.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_stop']
    end
  end

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
    "range(start: #{value})"
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
