class Balance::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  before_action :refresh_summaries_if_needed

  def index
    render formats: :turbo_stream
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    Summarizer.new(timeframe:).perform_now!
  end

  def calculator_now
    Calculator::Now.new(
      [
        :inverter_power,
        :balcony_inverter_power,
        :house_power,
        :heatpump_power,
        :wallbox_power,
        :battery_charging_power,
        :battery_discharging_power,
        :grid_import_power,
        :grid_export_power,
        :grid_export_limit,
        :heatpump_power_grid,
        :wallbox_power_grid,
        :house_power_grid,
        :battery_charging_power_grid,
        *SensorConfig.x.excluded_sensor_names.flat_map do |sensor_name|
          [sensor_name, :"#{sensor_name}_grid"]
        end,
        :car_battery_soc,
        :battery_soc,
        :system_status,
        :system_status_ok,
        :wallbox_car_connected,
        :case_temp,
      ],
    )
  end

  def calculator_range
    Calculator::Range.new(
      timeframe,
      calculations: [
        Queries::Calculation.new(:inverter_power, :sum, :sum),
        Queries::Calculation.new(:balcony_inverter_power, :sum, :sum),
        Queries::Calculation.new(:house_power, :sum, :sum),
        Queries::Calculation.new(:heatpump_power, :sum, :sum),
        Queries::Calculation.new(:wallbox_power, :sum, :sum),
        Queries::Calculation.new(:battery_charging_power, :sum, :sum),
        Queries::Calculation.new(:battery_discharging_power, :sum, :sum),
        Queries::Calculation.new(:grid_import_power, :sum, :sum),
        Queries::Calculation.new(:grid_export_power, :sum, :sum),
        Queries::Calculation.new(:heatpump_power_grid, :sum, :sum),
        Queries::Calculation.new(:wallbox_power_grid, :sum, :sum),
        Queries::Calculation.new(:house_power_grid, :sum, :sum),
        Queries::Calculation.new(:battery_charging_power_grid, :sum, :sum),
        *SensorConfig.x.excluded_sensor_names.flat_map do |sensor_name|
          [
            Queries::Calculation.new(sensor_name, :sum, :sum),
            Queries::Calculation.new(:"#{sensor_name}_grid", :sum, :sum),
          ]
        end,
      ],
    )
  end
end
