class Balance::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to root_path(sensor:, timeframe:)
    end
  end

  private

  def calculator_range
    Calculator::Range.new(timeframe, calculations:)
  end

  def calculations
    if sensor == :inverter_power
      [
        *(
          inverter_sensor_names.map do |sensor_name|
            Queries::Calculation.new(sensor_name, :sum, :sum)
          end
        ),
        (
          if timeframe.day?
            Queries::Calculation.new(:inverter_power_forecast, :sum, :sum)
          end
        ),
      ].compact
    else
      [Queries::Calculation.new(sensor, :sum, :sum)]
    end
  end

  def inverter_sensor_names
    if multi_inverter_enabled?
      ([:inverter_power] + SensorConfig.x.inverter_sensor_names).uniq
    else
      [:inverter_power]
    end
  end

  def multi_inverter_enabled?
    SensorConfig.x.multi_inverter? && ApplicationPolicy.multi_inverter?
  end
end
