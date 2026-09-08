module InfluxHelper
  @in_batch = false
  @write_api = Influx.client.create_write_api
  @delete_api = Influx.client.create_delete_api

  class << self
    attr_reader :write_api, :delete_api
  end

  # Whether this example put points into InfluxDB. The helper is mixed into
  # every example, so the flag starts out nil for each one and the after hook
  # can skip the delete request for the examples that wrote nothing.
  def influx_written?
    @influx_written.present?
  end

  def influx_batch(&)
    @points = []
    @in_batch = true
    begin
      yield
    ensure
      @in_batch = false
    end

    add_influx_points(@points)
  end

  def add_influx_point(name:, fields:, time: Time.current)
    point = { name:, fields: float_fields(fields), time: time.to_i }

    @in_batch ? @points << point : add_influx_points([point])
  end

  def add_influx_points(points)
    @influx_written = true

    InfluxHelper.write_api.write(
      data: points,
      bucket: Rails.configuration.x.influx.bucket,
      org: Rails.configuration.x.influx.org,
    )
  end

  # InfluxDB pins a field to the type it was first written with, so an example
  # writing an Integer where another wrote a Float has its points rejected -
  # and which of the two runs first depends on the random spec order.
  # Measurement values are floats in production anyway, so numbers go in as
  # floats regardless of how the example spelled them.
  def float_fields(fields)
    fields.symbolize_keys.transform_values do |value|
      value.is_a?(Numeric) ? value.to_f : value
    end
  end

  def delete_influx_data(
    start: Time.zone.at(0),
    stop: Time.zone.at((2**63) / 1_000_000_000)
  )
    @influx_written = false
    InfluxHelper.delete_api.delete(start, stop)
  end
end

RSpec.configure do |config|
  config.include InfluxHelper

  # Clean up InfluxDB data after each test, but NOT for system tests
  # System tests share InfluxDB data for performance.
  #
  # The delete is an HTTP round trip, and only a fraction of the examples write
  # points at all - the application never writes to InfluxDB, it only queries.
  # Skipping the request for an example that wrote nothing saves about 4 ms on
  # each of them.
  config.after do |example|
    next if example.metadata[:type] == :system
    next unless influx_written?

    delete_influx_data
  end
end
