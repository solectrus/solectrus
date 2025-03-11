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

  def calculator_now
    Calculator::Now.new(
      [
        :house_power,
        :house_power_grid,
        :grid_import_power,
        *SensorConfig.x.existing_custom_sensor_names.flat_map do |sensor_name|
          [sensor_name, :"#{sensor_name}_grid"]
        end,
        *SensorConfig.x.excluded_sensor_names,
      ],
    )
  end

  def calculator_range
    Calculator::Range.new(
      timeframe,
      calculations: [
        Queries::Calculation.new(:house_power, :sum, :sum),
        Queries::Calculation.new(:house_power_grid, :sum, :sum),
        Queries::Calculation.new(:grid_import_power, :sum, :sum),
        *SensorConfig.x.existing_custom_sensor_names.flat_map do |sensor_name|
          [
            Queries::Calculation.new(sensor_name, :sum, :sum),
            Queries::Calculation.new(:"#{sensor_name}_grid", :sum, :sum),
          ]
        end,
        *SensorConfig.x.excluded_sensor_names.map do |sensor|
          Queries::Calculation.new sensor, :sum, :sum
        end,
      ],
    )
  end
end
