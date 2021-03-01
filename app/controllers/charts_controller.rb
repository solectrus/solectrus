class ChartsController < ApplicationController
  include ParamsHandling

  def index
    respond_to do |format|
      format.json { render json: chart_options }
    end
  end

  private

  def chart_options
    if timeframe == 'now'
      chart_options_now
    elsif timeframe == 'day' && field == 'inverter_power'
      chart_options_day_inverter_power
    else
      chart_options_range
    end
  end

  def chart_options_now
    chart = PowerChart.new(measurements: ['SENEC'], fields: [field]).now

    {
      labels: chart.map { |element| element[0] },
      datasets: [
        {
          label: I18n.t("senec.#{field}"),
          data: chart.map { |element| element[1] },
          backgroundColor: 'rgba(79, 70, 229, 0.5)',
          borderColor: '#4F46E5',
          borderWidth: 2
        }
      ]
    }
  end

  def chart_options_day_inverter_power
    chart_power = PowerChart.new(measurements: %w[SENEC], fields: [:inverter_power]).day(timestamp)
    chart_forecast = PowerChart.new(measurements: %w[Forecast], fields: [:watt]).day(timestamp, filled: true)

    {
      labels: chart_power.map(&:first).presence || chart_forecast.map(&:first),
      datasets: [
        {
          label: I18n.t('senec.inverter_power'),
          data: chart_power.map { |element| element[1] },
          backgroundColor: 'rgba(79, 70, 229, 0.5)',
          borderColor: '#4F46E5',
          borderWidth: 2
        },

        {
          label: I18n.t('calculator.forecast'),
          data: chart_forecast.map { |element| element[1] },
          backgroundColor: '#dddddd',
          borderColor: '#dddddd',
          borderWidth: 2
        }
      ]
    }
  end

  def chart_options_range
    chart = PowerChart.new(measurements: ['SENEC'], fields: [field]).public_send(timeframe, timestamp)

    {
      labels: chart.map { |element| element[0] },
      datasets: [
        {
          label: I18n.t("senec.#{field}"),
          data: chart.map { |element| element[1] },
          backgroundColor: 'rgba(79, 70, 229, 0.5)',
          borderColor: '#4F46E5',
          borderWidth: 2
        }
      ]
    }
  end
end
