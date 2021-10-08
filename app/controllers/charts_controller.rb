class ChartsController < ApplicationController
  include ParamsHandling

  def index
    respond_to { |format| format.json { render json: chart_options } }
  end

  private

  # TODO: Refactor and move code to Chart::Component

  def chart_options
    if timeframe == 'now'
      chart_options_now
    elsif timeframe == 'day' && field == 'inverter_power'
      chart_options_day_inverter_power
    else
      chart_options_range
    end
  end

  def fields
    case field
    when 'bat_power'
      %w[bat_power_plus bat_power_minus]
    when 'grid_power'
      %w[grid_power_plus grid_power_minus]
    else
      [field]
    end
  end

  def chart_options_now
    chart = PowerChart.new(measurements: ['SENEC'], fields: fields).now

    {
      labels: chart[chart.keys.first].map(&:first),
      datasets:
        chart.map do |chart_field, data|
          {
            label: I18n.t("senec.#{chart_field}"),
            data: mapped_data(data, chart_field),
          }.merge(style_options(chart_field))
        end,
    }
  end

  def chart_options_day_inverter_power # rubocop:disable Metrics/CyclomaticComplexity
    {
      labels: (chart_inverter_power || chart_forecast)&.map(&:first),
      datasets: [
        {
          label: I18n.t('senec.inverter_power'),
          data: chart_inverter_power&.map(&:second),
        }.merge(style_options('inverter_power')),
        {
          label: I18n.t('calculator.forecast'),
          data: chart_forecast&.map(&:second),
        }.merge(style_options('forecast')),
      ],
    }
  end

  def chart_options_range
    chart =
      PowerChart
        .new(measurements: ['SENEC'], fields: fields)
        .public_send(timeframe, timestamp)

    {
      labels: chart[chart.keys.first]&.map(&:first),
      datasets:
        chart.map do |chart_field, data|
          {
            label: I18n.t("senec.#{chart_field}"),
            data: mapped_data(data, chart_field),
          }.merge(style_options(chart_field))
        end,
    }
  end

  def style_options(chart_field)
    {
      fill:
        if chart_field.in?(%w[grid_power_minus grid_power_plus])
          {
            target: 'origin',
            above: 'rgb(16, 185, 129)',
            below: 'rgb(239, 68, 68)',
          }
        else
          'origin'
        end,
      backgroundColor:
        case chart_field
        when 'forecast'
          '#ddd'
        when 'grid_power_minus'
          'rgb(16, 185, 129)'
        when 'grid_power_plus'
          'rgb(239, 68, 68)'
        else
          'rgba(79, 70, 229, 0.5)'
        end,
      borderWidth: 0,
    }
  end

  def mapped_data(data, chart_field)
    if fields.length == 1 ||
         chart_field.in?(%w[grid_power_minus bat_power_plus])
      data.map(&:second)
    else
      data.map { |x| -x.second }
    end
  end

  def chart_inverter_power
    @chart_inverter_power ||=
      PowerChart
        .new(measurements: %w[SENEC], fields: %w[inverter_power])
        .day(timestamp)[
        'inverter_power'
      ]
  end

  def chart_forecast
    @chart_forecast ||=
      PowerChart
        .new(measurements: %w[Forecast], fields: %w[watt])
        .day(timestamp, filled: true)[
        'watt'
      ]
  end
end
