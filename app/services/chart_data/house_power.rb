class ChartData::HousePower < ChartData::Base
  private

  def data
    {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: I18n.t("sensors.#{chart_sensor}"),
            data: data.map(&:second),
          }.merge(style(chart_sensor))
        end,
    }
  end

  def chart
    @chart ||= splitted_chart? ? splitted_chart : simple_chart
  end

  def simple_chart
    chart =
      PowerChart.new(sensors: [:house_power, *exclude_from_house_power]).call(
        timeframe,
        fill: !timeframe.current?,
      )
    return chart if chart[:house_power].nil? || exclude_from_house_power.blank?

    { house_power: adjusted_house_power(chart) }
  end

  def splitted_chart
    chart =
      PowerChart.new(
        sensors: [:house_power, :house_power_grid, *exclude_from_house_power],
      ).call(timeframe, fill: !timeframe.current?)

    if chart.key?(:house_power) && chart.key?(:house_power_grid)
      {
        house_power_pv: adjusted_house_power(chart),
        house_power_grid: chart[:house_power_grid],
      }
    else
      # No data for house_power_grid is present, return simple chart instead
      { house_power: adjusted_house_power(chart) }.compact
    end
  end

  def adjusted_house_power(power_chart)
    sensors_to_exclude = [:house_power_grid, *exclude_from_house_power].flatten

    power_chart[:house_power]&.map&.with_index do |house_power, index|
      # Exclude sensors (and grid part, if present) from house_power
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

  def exclude_from_house_power
    SensorConfig.x.exclude_from_house_power
  end

  def background_color(chart_sensor)
    {
      house_power: '#64748b', # bg-slate-500
      house_power_grid: '#7f1d1d', # bg-red-900
      house_power_pv: '#14532d', # bg-green-900
    }[
      chart_sensor
    ]
  end

  def style(chart_sensor)
    {
      fill: 'origin',
      # Base color, will be changed to gradient in JS
      backgroundColor: background_color(chart_sensor),
      borderWidth: 1,
      borderRadius: 5,
    }
  end

  def splitted_chart?
    return false unless SensorConfig.x.exists?(:house_power_grid)

    # Because data is only available hourly we can't use for line charts
    !timeframe.now? && !timeframe.day?
  end
end
