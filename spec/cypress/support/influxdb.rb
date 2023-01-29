module CypressRails::InfluxDB
  def influx_seed
    puts 'Seeding InfluxDB with data...'

    # Fill 2 hour window with 5 second intervals
    2
      .hours
      .step(0, -5) do |i|
        add_influx_point(
          name: 'SENEC',
          fields: {
            inverter_power: 9000,
            house_power: 900,
            bat_power_plus: 1000,
            bat_power_minus: 0,
            bat_fuel_charge: 40.0,
            wallbox_charge_power: 6000,
            grid_power_plus: 0,
            grid_power_minus: 1100,
          },
          time: i.seconds.ago,
        )
      end

    add_influx_point(name: 'Forecast', fields: { watt: 8000 }, time: 2.hour.ago)
    add_influx_point(name: 'Forecast', fields: { watt: 9000 })
    add_influx_point(
      name: 'Forecast',
      fields: {
        watt: 7000,
      },
      time: 1.hour.since,
    )
  end

  def influx_purge
    puts 'Purging InfluxDB data...'

    delete_influx_data
  end

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
