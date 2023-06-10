module CypressRails::InfluxDB
  def influx_seed
    puts 'Seeding InfluxDB with data...'

    # Fill 2 hour window with 5 second intervals
    2
      .hours
      .step(0, -5) do |i|
        add_influx_point(
          name: Rails.configuration.x.influx.measurement_pv,
          fields: {
            inverter_power: 9000,
            house_power: 900,
            bat_power_plus: 1000,
            bat_power_minus: 10,
            bat_fuel_charge: 40.0,
            wallbox_charge_power: 6000,
            grid_power_plus: 10,
            grid_power_minus: 1100,
            case_temp: 30.0,
            current_state: 'LADEN',
          },
          time: i.seconds.ago,
        )
      end

    {
      5.hours.ago => 3000,
      2.hours.ago => 8000,
      1.hour.ago => 9000,
      1.hour.since => 7000,
      4.hours.since => 4000,
    }.each do |time, watt|
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_forecast,
        fields: {
          watt:,
        },
        time:,
      )
    end
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
      bucket: Rails.configuration.x.influx.bucket,
      org: Rails.configuration.x.influx.org,
    )
  end

  def delete_influx_data(start: Time.zone.at(0), stop: 1.second.since)
    influx_client = Flux::Base.new.client
    delete_api = influx_client.create_delete_api

    delete_api.delete(start, stop)
  end
end
