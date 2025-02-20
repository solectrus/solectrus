class ChartData::HousePowerWithoutCustom < ChartData::Base
  private

  def data
    @data ||= {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: SensorConfig.x.name(chart_sensor),
            data: data.map(&:second),
            stack: chart_sensor == :other_power ? nil : 'Power-Splitter',
          }.merge(style(chart_sensor, split: chart.key?(:other_power_grid)))
        end,
    }
  end

  def chart
    @chart ||= splitting_allowed? ? splitted_chart : simple_chart
  end

  def simple_chart
    raw_chart =
      PowerChart.new(sensors: [:house_power, *excluded_sensor_names]).call(
        timeframe,
      )
    if raw_chart[:house_power].nil? || excluded_sensor_names.blank?
      return raw_chart
    end

    {
      other_power:
        map_house_power(raw_chart) { |index| other_power(raw_chart, index) },
    }
  end

  def splitted_chart
    raw_chart =
      PowerChart.new(
        sensors: [
          :house_power,
          grid_sensor,
          *excluded_sensor_names,
          *included_grid_sensor_names,
        ],
      ).call(timeframe)

    if raw_chart.key?(:house_power) && raw_chart.key?(grid_sensor)
      {
        other_power:
          map_house_power(raw_chart) { |index| other_power(raw_chart, index) },
        other_power_grid:
          map_house_power(raw_chart) do |index|
            other_power_grid(raw_chart, index)
          end,
        other_power_pv:
          map_house_power(raw_chart) do |index|
            other_power_pv(raw_chart, index)
          end,
      }
    else
      # No data for house_power_grid is present, return simple chart instead
      {
        other_power:
          map_house_power(raw_chart) { |index| other_power(raw_chart, index) },
      }
    end
  end

  def map_house_power(raw_chart)
    return [] unless raw_chart[:house_power]

    raw_chart[:house_power].map.with_index do |(timestamp, _), index|
      [timestamp, yield(index)]
    end
  end

  def other_power(raw_chart, index)
    house_power = raw_chart[:house_power][index]&.second
    excluded_sensor_names
      .reduce(house_power) do |acc, elem|
        acc.to_f - raw_chart.dig(elem, index)&.second.to_f
      end
      .clamp(0, nil)
  end

  def other_power_grid(raw_chart, index)
    house_power_grid = raw_chart[:house_power_grid][index]&.second
    return 0 unless house_power_grid

    custom_total_grid =
      SensorConfig.x.included_custom_sensor_names.sum do |sensor|
        raw_chart.dig("#{sensor}_grid", index)&.second.to_f
      end

    other_power = other_power(raw_chart, index)

    (house_power_grid - custom_total_grid).clamp(0, other_power)
  end

  def other_power_pv(raw_chart, index)
    other_power(raw_chart, index) - other_power_grid(raw_chart, index)
  end

  def excluded_sensor_names
    SensorConfig.x.excluded_sensor_names +
      SensorConfig.x.included_custom_sensor_names
  end

  def included_grid_sensor_names
    SensorConfig.x.included_custom_sensor_names.map { "#{it}_grid" }
  end

  def background_color(chart_sensor)
    {
      other_power: '#64748b', # bg-slate-500
      other_power_grid: '#dc2626', # bg-red-600
      other_power_pv: '#16a34a', # bg-green-600
    }[
      chart_sensor
    ]
  end

  def style(chart_sensor, split:)
    if split
      {
        fill: 'origin',
        # Base color, will be changed to gradient in JS
        backgroundColor: background_color(chart_sensor),
        barPercentage: chart_sensor == :other_power ? 0.7 : 1.3,
        categoryPercentage: 0.7,
        borderRadius:
          if chart_sensor == :other_power
            { topLeft: 5, bottomLeft: 0, topRight: 0, bottomRight: 0 }
          else
            0
          end,
        borderWidth:
          case chart_sensor # rubocop:disable Style/HashLikeCase
          when :other_power
            { top: 1, left: 1 }
          when :other_power_grid
            { right: 1 }
          when :other_power_pv
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

  def grid_sensor
    @grid_sensor ||=
      (SensorConfig.x.single_consumer? ? :grid_import_power : :house_power_grid)
  end

  def splitting_allowed?
    # As the data from the PowerSplitter is available in intervals only,
    # we cannot use it for line diagrams.
    return false if timeframe.short?

    SensorConfig.x.exists?(grid_sensor)
  end
end
