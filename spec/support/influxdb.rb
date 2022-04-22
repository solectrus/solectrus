module InfluxHelper
  def add_influx_point(name:, fields:, time: Time.current)
    influx_client = Flux::Base.new.client
    write_api = influx_client.create_write_api

    write_api.write(
      data: {
        name:,
        fields:,
        time: time.to_i,
      },
      bucket: ENV.fetch('INFLUX_BUCKET', nil),
      org: ENV.fetch('INFLUX_ORG', nil),
    )
  end

  def delete_influx_data(start: Time.zone.at(0), stop: Time.current)
    influx_client = Flux::Base.new.client
    delete_api = influx_client.create_delete_api

    delete_api.delete(start, stop)
  end
end

RSpec.configure do |config|
  config.include InfluxHelper

  config.before { delete_influx_data }
end
