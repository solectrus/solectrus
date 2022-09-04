class ChartData::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(field:, period:, timestamp:)
    super
    @field = field
    @period = period
    @timestamp = timestamp
  end
  attr_reader :field, :period, :timestamp

  def call
    if field == 'autarky'
      data_autarky
    elsif field == 'consumption'
      data_consumption
    elsif period == 'now'
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
      labels: now[now.keys.first]&.map(&:first),
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

  def data_autarky
    {
      labels: autarky&.map(&:first),
      datasets: [
        { label: I18n.t('senec.autarky'), data: autarky&.map(&:second) }.merge(
          style('autarky'),
        ),
      ],
    }
  end

  def data_consumption
    {
      labels: consumption&.map(&:first),
      datasets: [
        {
          label: I18n.t('calculator.consumption_quote'),
          data: consumption&.map(&:second),
        }.merge(style('consumption')),
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
    @now ||= PowerChart.new(measurements: ['SENEC'], fields:).now
  end

  def inverter_power
    @inverter_power ||=
      PowerChart.new(measurements: %w[SENEC], fields: %w[inverter_power]).day(
        timestamp,
      )[
        'inverter_power'
      ]
  end

  def autarky
    @autarky ||=
      if period == 'now'
        AutarkyChart.new(measurements: %w[SENEC]).now
      else
        AutarkyChart.new(measurements: %w[SENEC]).public_send(period, timestamp)
      end
  end

  def consumption
    @consumption ||=
      if period == 'now'
        ConsumptionChart.new(measurements: %w[SENEC]).now
      else
        ConsumptionChart.new(measurements: %w[SENEC]).public_send(
          period,
          timestamp,
        )
      end
  end

  def forecast
    @forecast ||=
      PowerChart.new(measurements: %w[Forecast], fields: %w[watt]).day(
        timestamp,
        fill: false,
        interpolate: true,
      )[
        'watt'
      ]
  end

  def range
    @range ||=
      PowerChart.new(measurements: ['SENEC'], fields:).public_send(
        period,
        timestamp,
      )
  end

  def style(chart_field)
    {
      fill: fill(chart_field),
      backgroundColor: background_color(chart_field),
      borderWidth: 0,
    }
  end

  def fill(chart_field)
    if chart_field.in?(%w[grid_power_minus grid_power_plus])
      {
        target: 'origin',
        above: '#16a34a', # bg-green-600
        below: '#dc2626', # bg-red-600
      }
    else
      'origin'
    end
  end

  def background_color(chart_field)
    case chart_field
    when 'forecast'
      '#ddd'
    when 'house_power'
      '#64748b' # bg-slate-500
    when 'grid_power_plus'
      '#dc2626' # bg-red-600
    when 'grid_power_minus', 'inverter_power'
      'rgba(22, 163, 74, 0.5)' # bg-green-600, 0.5 transparent
    when 'wallbox_charge_power'
      '#475569' # bg-slate-600
    when 'bat_power_minus', 'bat_power_plus', 'autarky', 'consumption'
      '#15803d' # bg-green-700
    end
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
