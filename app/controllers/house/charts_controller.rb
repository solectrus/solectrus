class House::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to house_home_path(sensor:, timeframe:)
    end
  end

  helper_method def chart_sensors
    [
      :house_power,
      *SensorConfig.x.included_custom_sensor_names.sort_by do |sensor_name|
        SensorConfig.x.display_name(sensor_name).downcase
      end,
      :house_power_without_custom,
    ]
  end
end
