class House::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  helper_method def chart_sensors
    [
      :house_power,
      '-',
      *SensorConfig.x.included_custom_sensor_names.sort_by do
        SensorConfig.x.name(it)
      end,
      '-',
      :house_power_without_custom,
    ]
  end
end
