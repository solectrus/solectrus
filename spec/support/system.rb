require 'capybara/rspec'
require 'capybara-playwright-driver'

Capybara.register_driver :my_playwright do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: ENV['PLAYWRIGHT_BROWSER']&.to_sym || :chromium,
    headless: (false unless ENV['CI'] || ENV['PLAYWRIGHT_HEADLESS']),
    locale: 'de-DE',
  )
end

module SystemTestHelpers # rubocop:disable Metrics/ModuleLength
  include InfluxHelper
  include ActiveSupport::Testing::TimeHelpers

  def travel_js(seconds)
    page.execute_script(<<~JS)
      window.clock.tick(#{seconds.in_milliseconds});
    JS
  end

  def influx_seed
    travel_to Time.zone.local(2022, 6, 21, 12, 0, 0)

    # Clean up any existing data first
    influx_purge

    # Use batch operation for massive performance improvement
    influx_batch do
      seed_pv
      seed_heatpump
      seed_forecast
      seed_car_battery_soc
    end

    summaries =
      (Rails.configuration.x.installation_date..Date.yesterday).map do |date|
        { date: }
      end
    Summary.insert_all(summaries) # rubocop:disable Rails/SkipsModelValidations

    create_summary(
      date: Date.current,
      updated_at: Date.tomorrow.middle_of_day,
      values: [
        [:inverter_power_1, :sum, 18_000],
        [:inverter_power_2, :sum, 2_000],
        [:inverter_power_forecast, :sum, 21_000],
        [:house_power, :sum, 1800],
        [:heatpump_power, :sum, 800],
        [:heatpump_power_grid, :sum, 200],
        [:grid_import_power, :sum, 20],
        [:grid_export_power, :sum, 2200],
        [:battery_charging_power, :sum, 2000],
        [:battery_discharging_power, :sum, 20],
        [:wallbox_power, :sum, 12_000],
        [:inverter_power_1, :max, 9000],
        [:inverter_power_2, :max, 1000],
        [:house_power, :max, 3000],
        [:heatpump_power, :max, 400],
        [:grid_import_power, :max, 500],
        [:grid_export_power, :max, 2500],
        [:battery_charging_power, :max, 1000],
        [:battery_discharging_power, :max, 100],
        [:wallbox_power, :max, 6000],
        [:battery_soc, :min, 40.0],
        [:car_battery_soc, :min, 30.0],
        [:case_temp, :min, 30.0],
        [:heatpump_heating_power, :sum, 2400],
        [:outdoor_temp, :avg, 10.0],
        [:outdoor_temp, :min, 5.0],
        [:outdoor_temp, :max, 15.0],
      ],
    )
  end

  def seed_pv
    # Fill 2 hour window with 5 second intervals
    2
      .hours
      .step(0, -5) do |i|
        add_influx_point(
          name: measurement_house_power,
          fields: {
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

        add_influx_point(
          name: measurement_inverter_power_1,
          fields: {
            field_inverter_power_1 => 9000,
          },
          time: i.seconds.ago,
        )

        add_influx_point(
          name: measurement_inverter_power_2,
          fields: {
            field_inverter_power_2 => 1000,
          },
          time: i.seconds.ago,
        )

        # Add main inverter_power measurement for primary inverter_power sensor
        add_influx_point(
          name: measurement_inverter_power,
          fields: {
            field_inverter_power => 10_000, # sum of inverter_power_1 + inverter_power_2
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

        add_influx_point(
          name: measurement_heatpump_heating_power,
          fields: {
            field_heatpump_heating_power => 1600,
            field_outdoor_temp => 10.0,
          },
          time: i.seconds.ago,
        )

        add_influx_point(
          name: measurement_heatpump_power_grid,
          fields: {
            field_heatpump_power_grid => 100,
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
    delete_influx_data
    delete_summaries
  end

  def create_summary(date:, updated_at: Time.current, values: [])
    Summary.create!(date:, updated_at:)

    SummaryValue.insert_all!(
      values.map do |v|
        { date:, field: v.first, aggregation: v.second, value: v.third }
      end,
    )
  end

  def delete_summaries
    ActiveRecord::Base.connection.execute(
      "TRUNCATE #{Summary.table_name} CASCADE",
    )
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system

  config.before(:each, type: :system) do
    driven_by :my_playwright

    # Set viewport size (recommended approach from capybara-playwright-driver)
    page.current_window.resize_to(1280, 800)

    # Uncomment this block to log Playwright console messages
    # page.driver.with_playwright_page do |page|
    #   page.on(
    #     'console',
    #     ->(msg) { puts "error: #{msg.text}" if msg.type == 'error' },
    #   )
    # end

    # Stub the version check so we don't have to hit the network
    UpdateCheck.class_eval do
      def latest
        { registration_status: 'complete', version: '1.0.0' }
      end
    end

    # Seed fresh data for each test to ensure isolation
    influx_seed
  end
end
