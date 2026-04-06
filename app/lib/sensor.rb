module Sensor
  CACHE_KEY = 'influx_has_data'.freeze
  private_constant :CACHE_KEY

  # Detects whether InfluxDB has ever received any measurement data.
  # The result is cached permanently once true, so the query runs
  # at most once per cache lifecycle.
  def self.data?
    return true if Rails.cache.read(CACHE_KEY)

    if influx_has_data?
      Rails.cache.write(CACHE_KEY, true)
      true
    else
      false
    end
  end

  def self.influx_has_data?
    bucket = Rails.configuration.x.influx.bucket

    query = if Influx.version >= Gem::Version.new('2.2')
              # InfluxDB 2.2+ supports the `start` parameter for schema.measurements,
              # allowing us to check all data without a time limit.
              <<~FLUX
                import "influxdata/influxdb/schema"
                schema.measurements(bucket: "#{bucket}", start: 0)
                |> limit(n: 1)
              FLUX
            else
              # InfluxDB < 2.2 does not support the `start` parameter for schema.measurements,
              # falling back to the default 30-day lookback window.
              <<~FLUX
                import "influxdata/influxdb/schema"
                schema.measurements(bucket: "#{bucket}")
                |> limit(n: 1)
              FLUX
            end

    result = Influx.query_api.query(query:)
    result.any? { |table| table.records.any? }
  rescue StandardError => e
    Rails.logger.error("Error checking InfluxDB for data: #{e.message}")
    false
  end
  private_class_method :influx_has_data?
end
