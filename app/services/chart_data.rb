class ChartData # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
  end
  attr_reader :sensor, :timeframe

  def call
    if sensor == :autarky
      data_autarky
    elsif sensor == :consumption
      data_consumption
    elsif timeframe.day? && sensor == :inverter_power
      data_day_inverter_power
    else
      data_generic
    end.to_json
  end

  private

  def data_generic
    {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: I18n.t("sensors.#{chart_sensor}"),
            data: mapped_data(data, chart_sensor),
          }.merge(style(chart_sensor))
        end,
    }
  end

  def data_day_inverter_power # rubocop:disable Metrics/CyclomaticComplexity
    {
      labels:
        (inverter_power || inverter_power_forecast)&.map do |x|
          x.first.to_i * 1000
        end,
      datasets: [
        {
          label: I18n.t('sensors.inverter_power'),
          data: inverter_power&.map(&:second),
        }.merge(style(:inverter_power)),
        {
          label: I18n.t('calculator.inverter_power_forecast'),
          data: inverter_power_forecast&.map(&:second),
        }.merge(style(:inverter_power_forecast)),
      ],
    }
  end

  def data_autarky
    {
      labels: autarky&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.autarky'),
          data: autarky&.map(&:second),
        }.merge(style(:autarky)),
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
        }.merge(style(:consumption)),
      ],
    }
  end

  def chart
    @chart ||=
      case sensor
      when :battery_soc
        battery_soc
      when :case_temp
        case_temp
      when :house_power
        house_power
      when :heatpump_power
        heatpump_power
      else
        generic
      end
  end

  def battery_soc
    MinMaxChart.new(sensors: %i[battery_soc], average: true).call(timeframe)
  end

  def case_temp
    MinMaxChart.new(sensors: %i[case_temp], average: false).call(timeframe)
  end

  def house_power
    house_power_without_heatpump_power(
      PowerChart.new(sensors: %i[house_power heatpump_power]).call(timeframe),
    )
  end

  def heatpump_power
    PowerChart.new(sensors: %i[heatpump_power]).call(
      timeframe,
      fill: !timeframe.current?,
    )
  end

  def generic
    PowerChart.new(sensors:).call(timeframe)
  end

  def inverter_power
    @inverter_power ||=
      PowerChart.new(sensors: %i[inverter_power]).call(timeframe)[
        :inverter_power
      ]
  end

  def autarky
    @autarky ||= AutarkyChart.new.call(timeframe)
  end

  def consumption
    @consumption ||= ConsumptionChart.new.call(timeframe)
  end

  def inverter_power_forecast
    @inverter_power_forecast ||=
      PowerChart.new(sensors: %i[inverter_power_forecast]).call(
        timeframe,
        fill: false,
        interpolate: true,
      )[
        :inverter_power_forecast
      ]
  end

  def house_power_without_heatpump_power(raw)
    return raw unless raw[:house_power] && raw[:heatpump_power]

    {
      house_power:
        raw[:house_power].map.with_index do |house_power, index|
          [
            house_power.first,
            if house_power.second
              [
                0,
                house_power.second -
                  raw.dig(:heatpump_power, index)&.second.to_f,
              ].max
            end,
          ]
        end,
    }
  end

  def style(chart_sensor)
    {
      fill: 'origin',
      # Base color, will be changed to gradient in JS
      backgroundColor: background_color(chart_sensor),
      borderWidth: 1,
      borderRadius: 5,
      # In min-max charts, show border around the **whole** bar (don't skip)
      borderSkipped:
        chart_sensor.in?(%i[battery_soc case_temp]) ? false : 'start',
    }
  end

  def background_color(chart_sensor)
    {
      inverter_power_forecast: '#cbd5e1', # bg-slate-300
      house_power: '#64748b', # bg-slate-500
      heatpump_power: '#475569', # bg-slate-600
      wallbox_power: '#334155', # bg-slate-700
      grid_power_import: '#dc2626', # bg-red-600
      grid_power_export: '#16a34a', # bg-green-600
      inverter_power: '#16a34a', # bg-green-600
      battery_discharging_power: '#15803d', # bg-green-700
      battery_charging_power: '#15803d', # bg-green-700
      autarky: '#15803d', # bg-green-700
      consumption: '#15803d', # bg-green-700
      battery_soc: '#38bdf8', # bg-sky-400
      case_temp: '#f87171', # bg-red-400
    }[
      chart_sensor
    ]
  end

  def mapped_data(data, chart_sensor)
    if sensors.length == 1 ||
         chart_sensor.in?(%i[grid_power_export battery_charging_power])
      data.map(&:second)
    else
      data.map { |x| x.second ? -x.second : nil }
    end
  end

  def sensors
    case sensor
    when :battery_power
      %i[battery_charging_power battery_discharging_power]
    when :grid_power
      %i[grid_power_import grid_power_export]
    else
      [sensor]
    end
  end
end
