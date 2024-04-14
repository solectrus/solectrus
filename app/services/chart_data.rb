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
    elsif sensor == :co2_reduction
      data_co2_reduction
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
        (inverter_power_chart || inverter_power_forecast_chart)&.map do |x|
          x.first.to_i * 1000
        end,
      datasets: [
        {
          label: I18n.t('sensors.inverter_power'),
          data: inverter_power_chart&.map(&:second),
        }.merge(style(:inverter_power)),
        {
          label: I18n.t('calculator.inverter_power_forecast'),
          data: inverter_power_forecast_chart&.map(&:second),
        }.merge(style(:inverter_power_forecast)),
      ],
    }
  end

  def data_autarky
    {
      labels: autarky_chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.autarky'),
          data: autarky_chart&.map(&:second),
        }.merge(style(:autarky)),
      ],
    }
  end

  def data_consumption
    {
      labels: consumption_chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.consumption_quote'),
          data: consumption_chart&.map(&:second),
        }.merge(style(:consumption)),
      ],
    }
  end

  def data_co2_reduction
    {
      labels: co2_reduction&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.co2_reduction'),
          data:
            co2_reduction&.map do |x|
              (x.second * co2_reduction_factor).round if x.second
            end,
        }.merge(style(:co2_reduction)),
      ],
    }
  end

  def co2_reduction_factor
    Calculator::Range::CO2_EMISION_FACTOR.fdiv(
      if timeframe.short?
        # g per hour
        24.0
      else
        # kg
        1000.0
      end,
    )
  end

  def chart
    @chart ||=
      case sensor
      when :battery_soc
        battery_soc_chart
      when :case_temp
        case_temp_chart
      when :house_power
        house_power_chart
      when :heatpump_power
        heatpump_power_chart
      when :wallbox_power
        wallbox_power_chart
      else
        generic_chart
      end
  end

  def house_power_chart
    if (timeframe.now? || timeframe.day?) ||
         !SensorConfig.x.exists?(:house_power_grid)
      house_power_simple_chart
    else
      house_power_splitted_chart
    end
  end

  def heatpump_power_chart
    if (timeframe.now? || timeframe.day?) ||
         !SensorConfig.x.exists?(:heatpump_power_grid)
      heatpump_power_simple_chart
    else
      heatpump_power_splitted_chart
    end
  end

  def wallbox_power_chart
    if (timeframe.now? || timeframe.day?) ||
         !SensorConfig.x.exists?(:wallbox_power_grid)
      wallbox_power_simple_chart
    else
      wallbox_power_splitted_chart
    end
  end

  def battery_soc_chart
    MinMaxChart.new(sensors: %i[battery_soc], average: true).call(timeframe)
  end

  def case_temp_chart
    MinMaxChart.new(sensors: %i[case_temp], average: false).call(timeframe)
  end

  def house_power_simple_chart
    exclude_from_house_power = SensorConfig.x.exclude_from_house_power

    chart =
      PowerChart.new(sensors: [:house_power, *exclude_from_house_power]).call(
        timeframe,
      )
    return chart if chart[:house_power].nil? || exclude_from_house_power.blank?

    # Exclude sensors from house_power
    {
      house_power:
        chart[:house_power].map.with_index do |house_power, index|
          [
            house_power.first,
            if house_power.second
              [
                0,
                exclude_from_house_power.reduce(
                  house_power.second,
                ) { |acc, elem| acc - chart.dig(elem, index)&.second.to_f },
              ].max
            end,
          ]
        end,
    }
  end

  def house_power_splitted_chart
    exclude_from_house_power = SensorConfig.x.exclude_from_house_power

    chart =
      PowerChart.new(
        sensors: [:house_power, :house_power_grid, *exclude_from_house_power],
      ).call(timeframe)
    return chart if chart[:house_power].nil?

    sensors_to_exclude = [:house_power_grid, *exclude_from_house_power].flatten

    {
      house_power_pv:
        chart[:house_power].map.with_index do |house_power, index|
          # Exclude sensors (and grid part) from house_power
          [
            house_power.first,
            if house_power.second
              [
                0,
                sensors_to_exclude.reduce(house_power.second) do |acc, elem|
                  acc - chart.dig(elem, index)&.second.to_f
                end,
              ].max
            end,
          ]
        end,
      house_power_grid: chart[:house_power_grid],
    }.compact
  end

  def heatpump_power_simple_chart
    PowerChart.new(sensors: %i[heatpump_power]).call(
      timeframe,
      fill: !timeframe.current?,
    )
  end

  def heatpump_power_splitted_chart
    chart =
      PowerChart.new(sensors: %i[heatpump_power heatpump_power_grid]).call(
        timeframe,
        fill: !timeframe.current?,
      )
    if chart[:heatpump_power].nil? || chart[:heatpump_power_grid].nil?
      return chart
    end

    {
      heatpump_power_pv:
        chart[:heatpump_power].map.with_index do |heatpump_power, index|
          # Exclude grid part
          [
            heatpump_power.first,
            if heatpump_power.second
              [
                0,
                [:heatpump_power_grid].reduce(
                  heatpump_power.second,
                ) { |acc, elem| acc - chart.dig(elem, index)&.second.to_f },
              ].max
            end,
          ]
        end,
      heatpump_power_grid: chart[:heatpump_power_grid],
    }.compact
  end

  def wallbox_power_simple_chart
    PowerChart.new(sensors: %i[wallbox_power]).call(timeframe)
  end

  def wallbox_power_splitted_chart
    chart =
      PowerChart.new(sensors: %i[wallbox_power wallbox_power_grid]).call(
        timeframe,
      )
    if chart[:wallbox_power].nil? || chart[:wallbox_power_grid].nil?
      return chart
    end

    {
      wallbox_power_pv:
        chart[:wallbox_power].map.with_index do |wallbox_power, index|
          # Exclude grid part
          [
            wallbox_power.first,
            if wallbox_power.second
              [
                0,
                [:wallbox_power_grid].reduce(
                  wallbox_power.second,
                ) { |acc, elem| acc - chart.dig(elem, index)&.second.to_f },
              ].max
            end,
          ]
        end,
      wallbox_power_grid: chart[:wallbox_power_grid],
    }.compact
  end

  def generic_chart
    PowerChart.new(sensors:).call(timeframe)
  end

  def inverter_power_chart_with_forecast
    @inverter_power_chart_with_forecast ||=
      PowerChart.new(sensors: %i[inverter_power inverter_power_forecast]).call(
        timeframe,
        interpolate: true,
      )
  end

  def inverter_power_chart
    inverter_power_chart_with_forecast[:inverter_power]
  end

  def inverter_power_forecast_chart
    inverter_power_chart_with_forecast[:inverter_power_forecast]
  end

  def autarky_chart
    @autarky_chart ||= AutarkyChart.new.call(timeframe)
  end

  def consumption_chart
    @consumption_chart ||= ConsumptionChart.new.call(timeframe)
  end

  def co2_reduction
    @co2_reduction ||=
      PowerChart.new(sensors: %i[inverter_power]).call(timeframe)[
        :inverter_power
      ]
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
      house_power_grid: '#7f1d1d', # bg-red-900
      house_power_pv: '#14532d', # bg-green-900
      heatpump_power: '#475569', # bg-slate-600
      heatpump_power_grid: '#7f1d1d', # bg-red-900
      heatpump_power_pv: '#14532d', # bg-green-900
      wallbox_power: '#334155', # bg-slate-700
      wallbox_power_grid: '#7f1d1d', # bg-red-900
      wallbox_power_pv: '#14532d', # bg-green-900
      grid_import_power: '#dc2626', # bg-red-600
      grid_export_power: '#16a34a', # bg-green-600
      inverter_power: '#16a34a', # bg-green-600
      battery_discharging_power: '#15803d', # bg-green-700
      battery_charging_power: '#15803d', # bg-green-700
      autarky: '#15803d', # bg-green-700
      consumption: '#15803d', # bg-green-700
      battery_soc: '#38bdf8', # bg-sky-400
      case_temp: '#f87171', # bg-red-400
      co2_reduction: '#0369a1', # bg-sky-700
    }[
      chart_sensor
    ]
  end

  def mapped_data(data, chart_sensor)
    if sensors.length == 1 ||
         chart_sensor.in?(%i[grid_export_power battery_charging_power])
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
      %i[grid_import_power grid_export_power]
    else
      [sensor]
    end
  end
end
