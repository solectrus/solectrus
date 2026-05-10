class Forecast::ChartsController < ApplicationController
  def show
    redirect_to forecast_path and return unless turbo_frame_request?

    render formats: :turbo_stream
  end

  private

  helper_method def id
    @id ||= params[:id]
  end

  helper_method def timeframe
    @timeframe ||=
      begin
        days = (params[:days] || 2).to_i
        end_date = Date.current + (days - 1).days
        Timeframe.new("#{Date.current}..#{end_date}")
      end
  end
end
