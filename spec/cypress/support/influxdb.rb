module CypressRails::InfluxDB # rubocop:disable Metrics/ModuleLength
  def influx_seed
    puts 'Seeding InfluxDB with data...'

    seed_pv
    seed_heatpump
    seed_forecast
    seed_car_battery_soc

    summaries =
      (Rails.configuration.x.installation_date..Date.yesterday).map do |date|
        { date: }
      end
    Summary.insert_all(summaries) # rubocop:disable Rails/SkipsModelValidations

    Summary.create! date: Date.current,
                    updated_at: Date.tomorrow.middle_of_day,
                    sum_inverter_power: 18_000,
                    sum_inverter_power_forecast: 19_000,
                    sum_house_power: 1800,
                    sum_heatpump_power: 800,
                    sum_grid_import_power: 20,
                    sum_grid_export_power: 2200,
                    sum_battery_charging_power: 2000,
                    sum_battery_discharging_power: 20,
                    sum_wallbox_power: 12_000,
                    max_inverter_power: 9000,
                    max_house_power: 3000,
                    max_heatpump_power: 400,
                    max_grid_import_power: 500,
                    max_grid_export_power: 2500,
                    max_battery_charging_power: 1000,
                    max_battery_discharging_power: 100,
                    max_wallbox_power: 6000,
                    min_battery_soc: 40.0,
                    min_car_battery_soc: 30.0,
                    min_case_temp: 30.0,
                    max_battery_soc: 70.0,
                    max_car_battery_soc: 80,
                    max_case_temp: 30.0
  end

  def seed_pv
    # Fill 2 hour window with 5 second intervals
    2
      .hours
      .step(0, -5) do |i|
        add_influx_point(
          name: measurement_inverter_power,
          fields: {
            field_inverter_power => 9000,
            field_house_power => 900,
            field_battery_charging_power => 1000,
            field_battery_discharging_power => 10,
            field_battery_soc => 40.0,
            field_wallbox_power => 6000,
            field_grid_import_power => 10,
            field_grid_export_power => 1100,
            field_grid_export_limit => 100,
            field_case_temp => 30.0,
            field_system_status => 'LADEN',
            field_system_status_ok => true,
          },
          time: i.seconds.ago,
        )
      end
  end

  def seed_heatpump
    # Fill 2 hour window with 5 second intervals
    2
      .hours
      .step(0, -5) do |i|
        add_influx_point(
          name: measurement_heatpump_power,
          fields: {
            field_heatpump_power => 400,
          },
          time: i.seconds.ago,
        )
      end
  end

  def seed_car_battery_soc
    # Fill 2 hour window with 15min intervals
    2
      .hours
      .step(0, -5.minutes) do |i|
        add_influx_point(
          name: measurement_car_battery_soc,
          fields: {
            field_car_battery_soc => 70,
          },
          time: i.seconds.ago,
        )
      end
  end

  def seed_forecast
    {
      5.hours.ago => 3000,
      2.hours.ago => 8000,
      1.hour.ago => 9000,
      1.hour.since => 7000,
      4.hours.since => 4000,
    }.each do |time, watt|
      add_influx_point(
        name: measurement_inverter_power_forecast,
        fields: {
          field_inverter_power_forecast => watt,
        },
        time:,
      )
    end
  end

  def influx_purge
    puts 'Purging InfluxDB data and summaries...'

    delete_influx_data
    delete_summaries
  end

  def add_influx_point(name:, fields:, time: Time.current)
    write_api = influx_client.create_write_api

    write_api.write(
      data: {
        name:,
        fields: fields.symbolize_keys,
        time: time.to_i,
      },
      bucket: Rails.configuration.x.influx.bucket,
      org: Rails.configuration.x.influx.org,
    )
  end

  def delete_influx_data(start: Time.zone.at(0), stop: 1.second.since)
    delete_api = influx_client.create_delete_api

    delete_api.delete(start, stop)
  end

  def influx_client
    @influx_client ||= Flux::Base.new.client
  end

  def delete_summaries
    ActiveRecord::Base.connection.truncate(Summary.table_name)
  end
end
