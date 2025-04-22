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
    write_api = influx_client.create_write_api

    write_api.write(
      data: points,
      bucket: Rails.configuration.x.influx.bucket,
      org: Rails.configuration.x.influx.org,
    )
  end

  def delete_influx_data(
    start: Time.zone.at(0),
    stop: Time.zone.at((2**63) / 1_000_000_000)
  )
    delete_api = influx_client.create_delete_api

    delete_api.delete(start, stop)
  end

  def influx_client
    @influx_client ||= Flux::Base.new.client
  end

  SensorConfig::SENSOR_NAMES.each do |name|
    define_method(:"field_#{name}") { SensorConfig.x.field(name) }

    define_method(:"measurement_#{name}") { SensorConfig.x.measurement(name) }
  end
end

RSpec.configure do |config|
  config.include InfluxHelper

  config.after { delete_influx_data }
end
