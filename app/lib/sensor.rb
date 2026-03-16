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
    flux = <<~FLUX
      import "influxdata/influxdb/schema"
      schema.measurements(bucket: "#{Rails.configuration.x.influx.bucket}", start: 0)
      |> limit(n: 1)
    FLUX

    result = InfluxClient.query_api.query(query: flux)
    result.any? { |table| table.records.any? }
  rescue StandardError
    false
  end
  private_class_method :influx_has_data?
end
