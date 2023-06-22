class ChartData # rubocop:disable Metrics/ClassLength
  def initialize(field:, timeframe:)
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
      labels: now[now.keys.first]&.map { |x| x.first.to_i * 1000 },
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
      labels: (inverter_power || forecast)&.map { |x| x.first.to_i * 1000 },
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
      labels: autarky&.map { |x| x.first.to_i * 1000 },
      datasets: [
        { label: I18n.t('senec.autarky'), data: autarky&.map(&:second) }.merge(
          style('autarky'),
        ),
      ],
    }
  end

  def data_consumption
    {
      labels: consumption&.map { |x| x.first.to_i * 1000 },
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
      labels: range[range.keys.first]&.map { |x| x.first.to_i * 1000 },
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
        MinMaxChart.new(
          measurements: [Rails.configuration.x.influx.measurement_pv],
          fields:,
          average: true,
        ).call(timeframe)
      when 'case_temp'
        MinMaxChart.new(
          measurements: [Rails.configuration.x.influx.measurement_pv],
          fields:,
          average: false,
        ).call(timeframe)
      else
        PowerChart.new(
          measurements: [Rails.configuration.x.influx.measurement_pv],
          fields:,
        ).call(timeframe)
      end
  end

  def inverter_power
    @inverter_power ||=
      PowerChart.new(
        measurements: [Rails.configuration.x.influx.measurement_pv],
        fields: %w[inverter_power],
      ).call(timeframe)[
        'inverter_power'
      ]
  end

  def autarky
    @autarky ||=
      AutarkyChart.new(
        measurements: [Rails.configuration.x.influx.measurement_pv],
      ).call(timeframe)
  end

  def consumption
    @consumption ||=
      ConsumptionChart.new(
        measurements: [Rails.configuration.x.influx.measurement_pv],
      ).call(timeframe)
  end

  def forecast
    @forecast ||=
      PowerChart.new(
        measurements: [Rails.configuration.x.influx.measurement_forecast],
        fields: %w[watt],
      ).call(timeframe, fill: false, interpolate: true)[
        'watt'
      ]
  end

  def range
    @range ||=
      case field
      when 'bat_fuel_charge'
        MinMaxChart.new(
          measurements: [Rails.configuration.x.influx.measurement_pv],
          fields:,
          average: true,
        ).call(timeframe)
      when 'case_temp'
        MinMaxChart.new(
          measurements: [Rails.configuration.x.influx.measurement_pv],
          fields:,
          average: false,
        ).call(timeframe)
      else
        PowerChart.new(
          measurements: [Rails.configuration.x.influx.measurement_pv],
          fields:,
        ).call(timeframe)
      end
  end

  def style(chart_field)
    {
      fill: 'origin',
      # Base color, will be changed to gradient in JS
      backgroundColor: background_color(chart_field),
      borderWidth: 0.5,
      # In min-max charts, show border around the **whole** bar (don't skip)
      borderSkipped:
        chart_field.in?(%w[bat_fuel_charge case_temp]) ? false : 'start',
    }
  end

  def background_color(chart_field)
    {
      'forecast' => '#cbd5e1', # bg-slate-300
      'house_power' => '#64748b', # bg-slate-500
      'grid_power_plus' => '#dc2626', # bg-red-600
      'grid_power_minus' => '#16a34a', # bg-green-600
      'inverter_power' => '#16a34a', # bg-green-600
      'wallbox_charge_power' => '#475569', # bg-slate-600
      'bat_power_minus' => '#15803d', # bg-green-700
      'bat_power_plus' => '#15803d', # bg-green-700
      'autarky' => '#15803d', # bg-green-700
      'consumption' => '#15803d', # bg-green-700
      'bat_fuel_charge' => '#38bdf8', # bg-sky-400
      'case_temp' => '#f87171', # bg-red-400
    }[
      chart_field
    ]
  end

  def mapped_data(data, chart_field)
    if fields.length == 1 ||
         chart_field.in?(%w[grid_power_minus bat_power_plus])
      data.map(&:second)
    else
      data.map { |x| x.second ? -x.second : nil }
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
