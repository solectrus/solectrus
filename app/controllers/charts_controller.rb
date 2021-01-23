class ChartsController < ApplicationController
  include ParamsHandling

  def index
    respond_to do |format|
      format.json { render json: chart }
    end
  end

  private

  helper_method def chart
    @chart ||= if timeframe == 'now'
      [
        { name: field, data: PowerChart.new(measurements: ['SENEC'], fields: [field]).now }
      ]
    elsif timeframe == 'day' && field == 'inverter_power'
      [
        { name: 'inverter_power', data: PowerChart.new(measurements: %w[SENEC], fields: [:inverter_power]).day(timestamp) },
        { name: 'forecast',       data: PowerChart.new(measurements: %w[Forecast], fields: [:watt]).day(timestamp, filled: true) }
      ]
    else
      [
        { name: field, data: PowerChart.new(measurements: ['SENEC'], fields: [field]).public_send(timeframe, timestamp) }
      ]
    end
  end
end
