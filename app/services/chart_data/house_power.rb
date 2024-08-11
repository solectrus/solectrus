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
            stack: chart_sensor == :house_power ? nil : 'Power-Splitter',
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

    { house_power: adjusted_house_power(chart, exclude_grid: false) }
  end

  def splitted_chart
    chart =
      PowerChart.new(
        sensors: [:house_power, :house_power_grid, *exclude_from_house_power],
      ).call(timeframe, fill: !timeframe.current?)

    result =
      if chart.key?(:house_power) && chart.key?(:house_power_grid)
        {
          house_power: adjusted_house_power(chart, exclude_grid: false),
          house_power_grid: chart[:house_power_grid],
          house_power_pv: adjusted_house_power(chart, exclude_grid: true),
        }
      else
        # No data for house_power_grid is present, return simple chart instead
        {
          house_power: adjusted_house_power(chart, exclude_grid: false),
        }.compact
      end

    # Ensure house_power_grid is not higher than house_power
    result[:house_power_grid]&.each_with_index do |array, index|
      timestamp, house_power_grid = array
      house_power = result[:house_power][index]&.second

      result[:house_power_grid][index] = [
        timestamp,
        house_power_grid&.clamp(0, house_power),
      ]
    end

    result
  end

  def adjusted_house_power(power_chart, exclude_grid:) # rubocop:disable Metrics/CyclomaticComplexity
    sensors_to_exclude = [
      exclude_from_house_power,
      (:house_power_grid if exclude_grid),
    ].flatten

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

  def exclude_from_house_power
    SensorConfig.x.exclude_from_house_power
  end

  def background_color(chart_sensor)
    {
      house_power: '#64748b', # bg-slate-500
      house_power_grid: '#dc2626', # bg-red-600
      house_power_pv: '#16a34a', # bg-green-600
    }[
      chart_sensor
    ]
  end

  def style(chart_sensor)
    if splitted_chart?
      {
        fill: 'origin',
        # Base color, will be changed to gradient in JS
        backgroundColor: background_color(chart_sensor),
        barPercentage: chart_sensor == :house_power ? 0.7 : 1.3,
        categoryPercentage: 0.7,
        borderRadius:
          if chart_sensor == :house_power
            { topLeft: 5, bottomLeft: 0, topRight: 0, bottomRight: 0 }
          else
            0
          end,
        borderWidth:
          case chart_sensor # rubocop:disable Style/HashLikeCase
          when :house_power
            { top: 1, left: 1 }
          when :house_power_grid
            { right: 1 }
          when :house_power_pv
            { top: 1, right: 1 }
          end,
        borderColor: background_color(chart_sensor),
      }
    else
      {
        fill: 'origin',
        # Base color, will be changed to gradient in JS
        backgroundColor: background_color(chart_sensor),
        borderWidth: 1,
        borderRadius: 5,
        borderSkipped: 'start',
      }
    end
  end

  def splitted_chart?
    return false unless SensorConfig.x.exists?(:house_power_grid)

    # Because data is only available hourly we can't use for line charts
    !timeframe.now? && !timeframe.day?
  end
end
