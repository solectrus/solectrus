class ChartData::Component < ViewComponent::Base
  def initialize(field:, period:, timestamp:)
    super
    @field = field
    @period = period
    @timestamp = timestamp
  end
  attr_reader :field, :period, :timestamp

  def call
    if period == 'now'
      data_now
    elsif period == 'day' && field == 'inverter_power'
      data_day_inverter_power
    else
      data_range
    end.to_json
  end

  private

  def data_now
    {
      labels: now[now.keys.first].map(&:first),
      datasets:
        now.map do |chart_field, data|
          {
            label: I18n.t("senec.#{chart_field}"),
            data: mapped_data(data, chart_field),
          }.merge(style(chart_field))
        end,
    }
  end

  def data_day_inverter_power # rubocop:disable Metrics/CyclomaticComplexity
    {
      labels: (inverter_power || forecast)&.map(&:first),
      datasets: [
        {
          label: I18n.t('senec.inverter_power'),
          data: inverter_power&.map(&:second),
        }.merge(style('inverter_power')),
        {
          label: I18n.t('calculator.forecast'),
          data: forecast&.map(&:second),
        }.merge(style('forecast')),
      ],
    }
  end

  def data_range
    {
      labels: range[range.keys.first]&.map(&:first),
      datasets:
        range.map do |chart_field, data|
          {
            label: I18n.t("senec.#{chart_field}"),
            data: mapped_data(data, chart_field),
          }.merge(style(chart_field))
        end,
    }
  end

  def now
    @now ||= PowerChart.new(measurements: ['SENEC'], fields: fields).now
  end

  def inverter_power
    @inverter_power ||=
      PowerChart
        .new(measurements: %w[SENEC], fields: %w[inverter_power])
        .day(timestamp)[
        'inverter_power'
      ]
  end

  def forecast
    @forecast ||=
      PowerChart
        .new(measurements: %w[Forecast], fields: %w[watt])
        .day(timestamp, fill: false, interpolate: true)[
        'watt'
      ]
  end

  def range
    @range ||=
      PowerChart
        .new(measurements: ['SENEC'], fields: fields)
        .public_send(period, timestamp)
  end

  def style(chart_field)
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
end
