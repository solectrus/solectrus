class House::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to house_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  helper_method def chart_sensors
    [
      :house_power,
      *Sensor::Config
        .house_power_included_custom_sensors
        .sort_by { |sensor| sensor.display_name.downcase }
        .map(&:name),
      :house_power_without_custom,
    ]
  end
end
