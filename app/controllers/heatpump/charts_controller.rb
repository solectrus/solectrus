class Heatpump::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to heatpump_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  private

  helper_method def chart_sensors
    Sensor::Config.chart_sensors.filter_map do |sensor|
      sensor.name if sensor.category == :heatpump
    end
  end
end
