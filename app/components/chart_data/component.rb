class ChartData::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(field:, timeframe:)
    super
    @field = field
    @timeframe = timeframe
  end
  attr_reader :field, :timeframe

  def call
    if field == 'autarky'
      data_autarky
    elsif field == 'consumption'
      data_consumption
    elsif timeframe.now?
      data_now
    elsif timeframe.day? && field == 'inverter_power'
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
    @now ||=
      case field
      when 'bat_fuel_charge'
        MinMaxChart.new(measurements: %w[SENEC], fields:, average: true).call(
          timeframe,
        )
      when 'case_temp'
        MinMaxChart.new(measurements: %w[SENEC], fields:, average: false).call(
          timeframe,
        )
      else
        PowerChart.new(measurements: ['SENEC'], fields:).call(timeframe)
      end
  end

  def inverter_power
    @inverter_power ||=
      PowerChart.new(measurements: %w[SENEC], fields: %w[inverter_power]).call(
        timeframe,
      )[
        'inverter_power'
      ]
  end

  def autarky
    @autarky ||= AutarkyChart.new(measurements: %w[SENEC]).call(timeframe)
  end

  def consumption
    @consumption ||=
      ConsumptionChart.new(measurements: %w[SENEC]).call(timeframe)
  end

  def forecast
    @forecast ||=
      PowerChart.new(measurements: %w[Forecast], fields: %w[watt]).call(
        timeframe,
        fill: false,
        interpolate: true,
      )[
        'watt'
      ]
  end

  def range
    @range ||=
      case field
      when 'bat_fuel_charge'
        MinMaxChart.new(measurements: %w[SENEC], fields:, average: true).call(
          timeframe,
        )
      when 'case_temp'
        MinMaxChart.new(measurements: %w[SENEC], fields:, average: false).call(
          timeframe,
        )
      else
        PowerChart.new(measurements: ['SENEC'], fields:).call(timeframe)
      end
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
    {
      'forecast' => '#cbd5e1', # bg-slate-300
      'house_power' => '#64748b', # bg-slate-500
      'grid_power_plus' => '#dc2626', # bg-red-600
      'grid_power_minus' => 'rgba(22, 163, 74, 0.5)', # bg-green-600, 50% transparent
      'inverter_power' => 'rgba(22, 163, 74, 0.5)', # bg-green-600, 50% transparent
      'wallbox_charge_power' => '#475569', # bg-slate-600
      'bat_power_minus' => '#15803d', # bg-green-700
      'bat_power_plus' => '#15803d', # bg-green-700
      'autarky' => '#15803d', # bg-green-700
      'consumption' => '#15803d', # bg-green-700
      'bat_fuel_charge' => '#60a5fa', # bg-blue-400
      'case_temp' => '#991b1b', # bg-red-800
    }[
      chart_field
    ]
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
