class House::StatsController < ApplicationController
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
      system_status: nil,
      house_power: :sum_house_power_sum,
      house_power_grid: :sum_house_power_grid_sum,
      **(1..SensorConfig::CUSTOM_SENSOR_COUNT)
        .filter_map do |index|
          sensor_key = format('custom_power_%02d', index).to_sym
          if SensorConfig.x.exists?(sensor_key)
            [sensor_key, format('sum_custom_power_%02d_sum', index).to_sym]
          end
        end
        .to_h,
      **excluded_sensors,
      # Add these for PowerSplitterCorrector only
      grid_import_power: :sum_grid_import_power_sum,
      heatpump_power: :sum_heatpump_power_sum,
      heatpump_power_grid: :sum_heatpump_power_grid_sum,
      wallbox_power: :sum_wallbox_power_sum,
      wallbox_power_grid: :sum_wallbox_power_grid_sum,
    }
  end

  def excluded_sensors
    SensorConfig.x.exclude_from_house_power.index_with do |sensor|
      :"sum_#{sensor}_sum"
    end
  end
end
