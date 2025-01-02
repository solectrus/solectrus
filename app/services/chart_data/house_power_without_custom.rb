class ChartData::HousePowerWithoutCustom < ChartData::Base
  private

  def data
    {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: SensorConfig.x.name(chart_sensor),
            data: data.map(&:second),
          }.merge(style)
        end,
    }
  end

  def chart
    @chart ||=
      begin
        raw_chart =
          PowerChart.new(sensors: [:house_power, *sensors_to_exclude]).call(
            timeframe,
            fill: !timeframe.current?,
          )

        if raw_chart[:house_power].nil? || sensors_to_exclude.blank?
          raw_chart
        else
          { house_power_without_custom: adjusted_house_power(raw_chart) }
        end
      end
  end

  def style
    {
      fill: 'origin',
      # Base color, will be changed to gradient in JS
      backgroundColor: '#64748b', # bg-slate-500
      borderWidth: 1,
      borderRadius: 5,
      borderSkipped: 'start',
    }
  end

  def adjusted_house_power(power_chart)
    power_chart[:house_power]&.map&.with_index do |house_power, index|
      # Exclude given sensors from house_power
      timestamp, power = house_power
      [
        timestamp,
        if power
          [
            0,
            sensors_to_exclude.reduce(power) do |acc, elem|
              acc - power_chart.dig(elem, index)&.second.to_f
            end,
          ].max
        end,
      ]
    end
  end

  def sensors_to_exclude
    @sensors_to_exclude ||=
      (
        SensorConfig.x.excluded_sensor_names +
          SensorConfig.x.existing_custom_sensor_names
      ).uniq
  end
end
