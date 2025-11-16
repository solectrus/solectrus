class Forecast::ChartsController < ApplicationController
  def show
    redirect_to forecast_path and return unless turbo_frame_request?

    render formats: :turbo_stream
  end

  private

  helper_method def chart_name
    @chart_name ||= params[:id]
  end

  helper_method def timeframe
    @timeframe ||= Timeframe.new("#{Date.current}..#{Date.current + 7.days}")
  end

  helper_method def forecast_days
    return unless chart_name == 'inverter_power'

    @forecast_days ||=
      Sensor::Chart::InverterPowerForecast.new(timeframe:).actual_days
  end
end
