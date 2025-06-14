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
    Calculator::Range.new(
      timeframe,
      calculations: [
        Queries::Calculation.new(sensor, :sum, :sum),
        (
          if timeframe.day? && sensor == :inverter_power
            Queries::Calculation.new(:inverter_power_forecast, :sum, :sum)
          end
        ),
      ].compact,
    )
  end
end
