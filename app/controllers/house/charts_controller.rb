class House::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  helper_method def chart_sensors
    %i[house_power] + SensorConfig.x.included_custom_sensor_names
  end
end