module InfluxHelper
  @in_batch = false

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
    point = { name:, fields: fields.symbolize_keys, time: time.to_i }

    @in_batch ? @points << point : add_influx_points([point])
  end

  def add_influx_points(points)
    InfluxClient.write_api.write(
      data: points,
      bucket: Rails.configuration.x.influx.bucket,
      org: Rails.configuration.x.influx.org,
    )
  end

  def delete_influx_data(
    start: Time.zone.at(0),
    stop: Time.zone.at((2**63) / 1_000_000_000)
  )
    InfluxClient.delete_api.delete(start, stop)
  end
end

RSpec.configure do |config|
  config.include InfluxHelper

  config.after { delete_influx_data }
end
