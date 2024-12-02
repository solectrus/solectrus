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

  def calculations
    {
      inverter_power: :sum_inverter_power_sum,
      house_power: :sum_house_power_sum,
      heatpump_power: :sum_heatpump_power_sum,
      wallbox_power: :sum_wallbox_power_sum,
      battery_charging_power: :sum_battery_charging_power_sum,
      battery_discharging_power: :sum_battery_discharging_power_sum,
      grid_import_power: :sum_grid_import_power_sum,
      grid_export_power: :sum_grid_export_power_sum,
      heatpump_power_grid: :sum_heatpump_power_grid_sum,
      wallbox_power_grid: :sum_wallbox_power_grid_sum,
      house_power_grid: :sum_house_power_grid_sum,
      **excluded_sensors,
    }
  end

  def excluded_sensors
    SensorConfig.x.exclude_from_house_power.index_with do |sensor|
      :"sum_#{sensor}_sum"
    end
  end
end
