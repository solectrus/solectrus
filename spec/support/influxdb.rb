module InfluxHelper
  @in_batch = false
  @write_api = Influx.client.create_write_api
  @delete_api = Influx.client.create_delete_api

  class << self
    attr_reader :write_api, :delete_api
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
    InfluxHelper.delete_api.delete(start, stop)
  end
end

RSpec.configure do |config|
  config.include InfluxHelper

  # Clean up InfluxDB data after each test, but NOT for system tests
  # System tests share InfluxDB data for performance
  config.after do |example|
    delete_influx_data unless example.metadata[:type] == :system
  end
end
