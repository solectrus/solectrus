require 'capybara/rspec'
require 'capybara-playwright-driver'

Capybara.register_driver :my_playwright do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: ENV['PLAYWRIGHT_BROWSER']&.to_sym || :chromium,
    headless: (false unless ENV['CI'] || ENV['PLAYWRIGHT_HEADLESS']),
    locale: 'de-DE',
    viewport: {
      width: 1280,
      height: 800,
    },
    reduced_motion: :reduce,
  )
end

module SystemTestHelpers # rubocop:disable Metrics/ModuleLength
  include InfluxHelper
  include ActiveSupport::Testing::TimeHelpers
  include SensorTestHelpers

  def travel_js(seconds)
    page.execute_script(<<~JS)
      window.clock.tick(#{seconds.in_milliseconds});
    JS
  end

  def influx_seed(base_time: Time.zone.local(2022, 6, 21, 12, 0, 0)) # rubocop:disable Metrics/MethodLength
    # Use batch operation for massive performance improvement
    influx_batch do
      seed_pv(base_time:)
      seed_heatpump(base_time:)
      seed_forecast(base_time:)
      seed_car_battery_soc(base_time:)
    end

    summaries =
      (
        Rails.configuration.x.installation_date..base_time.to_date.yesterday
      ).map { |date| { date: } }
    Summary.insert_all(summaries) # rubocop:disable Rails/SkipsModelValidations

    create_summary(
      date: base_time.to_date,
      updated_at: base_time.to_date.tomorrow.middle_of_day,
      values: [
        [:inverter_power, :sum, 20_000], # Total: inverter_power_1 + inverter_power_2
        [:inverter_power, :max, 10_000], # Max: 9000 + 1000
        [:inverter_power_1, :sum, 18_000],
        [:inverter_power_2, :sum, 2_000],
        [:inverter_power_forecast, :sum, 21_000],
        [:house_power, :sum, 1800],
        [:house_power_grid, :sum, 1000],
        [:heatpump_power, :sum, 800],
        [:heatpump_power_grid, :sum, 200],
        [:grid_import_power, :sum, 20],
        [:grid_export_power, :sum, 2200],
        [:battery_charging_power, :sum, 2000],
        [:battery_discharging_power, :sum, 20],
        [:wallbox_power, :sum, 12_000],
        [:custom_power_01, :sum, 1500],
        [:custom_power_01_grid, :sum, 400],
        [:inverter_power_1, :max, 9000],
        [:inverter_power_2, :max, 1000],
        [:house_power, :max, 3000],
        [:heatpump_power, :max, 400],
        [:grid_import_power, :max, 500],
        [:grid_export_power, :max, 2500],
        [:battery_charging_power, :max, 1000],
        [:battery_discharging_power, :max, 100],
        [:wallbox_power, :max, 6000],
        [:custom_power_01, :max, 200],
        [:battery_soc, :min, 40.0],
        [:battery_soc, :max, 90.0],
        [:car_battery_soc, :min, 30.0],
        [:car_battery_soc, :max, 85.0],
        [:case_temp, :min, 30.0],
        [:heatpump_heating_power, :sum, 2400],
        [:outdoor_temp, :avg, 10.0],
        [:outdoor_temp, :min, 5.0],
        [:outdoor_temp, :max, 15.0],
      ],
    )
  end

  def seed_pv(base_time:) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
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
          time: base_time - i.seconds,
        )

        add_influx_point(
          name: measurement_house_power_grid,
          fields: {
            field_house_power_grid => 250,
          },
          time: base_time - i.seconds,
        )

        add_influx_point(
          name: measurement_custom_power_01,
          fields: {
            field_custom_power_01 => 200,
          },
          time: base_time - i.seconds,
        )

        add_influx_point(
          name: measurement_custom_power_01_grid,
          fields: {
            field_custom_power_01_grid => 50,
          },
          time: base_time - i.seconds,
        )

        add_influx_point(
          name: measurement_inverter_power_1,
          fields: {
            field_inverter_power_1 => 9000,
          },
          time: base_time - i.seconds,
        )

        add_influx_point(
          name: measurement_inverter_power_2,
          fields: {
            field_inverter_power_2 => 1000,
          },
          time: base_time - i.seconds,
        )

        # Add main inverter_power measurement for primary inverter_power sensor
        add_influx_point(
          name: measurement_inverter_power,
          fields: {
            field_inverter_power => 10_000, # sum of inverter_power_1 + inverter_power_2
          },
          time: base_time - i.seconds,
        )
      end
  end

  def seed_heatpump(base_time:)
    # Fill 2 hour window with 5 second intervals
    2
      .hours
      .step(0, -5) do |i|
        add_influx_point(
          name: measurement_heatpump_power,
          fields: {
            field_heatpump_power => 400,
          },
          time: base_time - i.seconds,
        )

        add_influx_point(
          name: measurement_heatpump_heating_power,
          fields: {
            field_heatpump_heating_power => 1600,
            field_outdoor_temp => 10.0,
          },
          time: base_time - i.seconds,
        )

        add_influx_point(
          name: measurement_heatpump_power_grid,
          fields: {
            field_heatpump_power_grid => 100,
          },
          time: base_time - i.seconds,
        )
      end
  end

  def seed_car_battery_soc(base_time:)
    # Fill 2 hour window with 15min intervals
    2
      .hours
      .step(0, -5.minutes) do |i|
        add_influx_point(
          name: measurement_car_battery_soc,
          fields: {
            field_car_battery_soc => 70,
          },
          time: base_time - i.seconds,
        )
      end
  end

  def seed_forecast(base_time:)
    # Seed forecast data (for next 3 days)
    3
      .days
      .step(0, -1.hour) do |i|
        time = base_time + i.seconds
        hour = time.hour
        day_offset = (time.to_date - base_time.to_date).to_i

        # Solar power: peak at 1pm, zero at night
        inverter_power_forecast =
          (
            if hour.between?(6, 20)
              (Math.cos(((hour - 13).abs / 7.0) * Math::PI / 2) * 8500).round
            else
              0
            end
          )

        add_influx_point(
          name: measurement_inverter_power_forecast,
          fields: {
            field_inverter_power_forecast => inverter_power_forecast,
          },
          time:,
        )

        # Temperature: base varies by day, daily sine curve
        outdoor_temp_forecast =
          (
            20.0 - (day_offset * 0.5) +
              (Math.sin((hour - 6) * Math::PI / 12) * 5.0)
          ).round(1)

        add_influx_point(
          name: measurement_outdoor_temp_forecast,
          fields: {
            field_outdoor_temp_forecast => outdoor_temp_forecast,
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

  # Seed test data once for all system tests (major performance optimization!)
  # This runs ONCE before any system tests start
  config.before(:suite) do
    # Only seed if we're actually running system tests
    if RSpec.configuration.files_to_run.any? { |f| f.include?('spec/system') }
      extend SystemTestHelpers

      influx_seed
    end
  end

  config.before(:each, type: :system) do
    driven_by :my_playwright

    # Set time for each test to match the seeded data
    # Data was seeded with this base time in before(:suite)
    travel_to Time.zone.local(2022, 6, 21, 12, 0, 0)
  end

  # Clear browser state after each test to prevent state leakage
  # This allows Capybara to reuse the browser session between tests
  config.after(:each, type: :system) do
    # Clear cookies via Playwright driver
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.clear_cookies
    end

    # Don't reset the Capybara session - this allows browser reuse
    # Capybara.reset_sessions! would kill the browser
  end

  # Clean up test data after all system tests are complete
  config.after(:suite) do
    # Only cleanup if system tests were run
    if RSpec.configuration.files_to_run.any? { |f| f.include?('spec/system') }
      extend SystemTestHelpers

      influx_purge
    end
  end
end
