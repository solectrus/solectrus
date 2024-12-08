class House::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  helper_method def chart_sensors
    %i[house_power] +
      (1..SensorConfig::CUSTOM_SENSOR_COUNT).map do |i|
        format('custom_power_%02d', i).to_sym
      end - SensorConfig.x.custom_excluded_from_house_power
  end
end
