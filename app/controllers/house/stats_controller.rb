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
      grid_import_power: :sum_grid_import_power_sum,
      **(
        SensorConfig.x.existing_custom_sensor_names.index_with do |sensor_name|
          :"sum_#{sensor_name}_sum"
        end
      ),
      **(
        SensorConfig.x.excluded_sensor_names.index_with do |sensor|
          :"sum_#{sensor}_sum"
        end
      ),
    }
  end
end
