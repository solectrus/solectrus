class ChartData::HousePowerWithoutCustom < ChartData::Base # rubocop:disable Metrics/ClassLength
  private

  def data
    @data ||= {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            id: chart_sensor,
            label: SensorConfig.x.display_name(chart_sensor),
            data: data.map(&:second),
            stack:
              (
                if chart_sensor == :house_power_without_custom
                  nil
                else
                  'Power-Splitter'
                end
              ),
          }.merge(
            style(
              chart_sensor,
              split: chart.key?(:house_power_without_custom_grid),
            ),
          )
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
      house_power_without_custom:
        map_house_power(raw_chart) do |index|
          house_power_without_custom(raw_chart, index)
        end,
    }
  end

  def splitted_chart
    raw_chart =
      PowerChart.new(
        sensors: [
          :house_power,
          :house_power_grid,
          grid_sensor,
          *excluded_sensor_names,
          *included_grid_sensor_names,
        ],
      ).call(timeframe)

    if raw_chart.key?(:house_power) && raw_chart.key?(grid_sensor)
      {
        house_power_without_custom:
          map_house_power(raw_chart) do |index|
            house_power_without_custom(raw_chart, index)
          end,
        house_power_without_custom_grid:
          map_house_power(raw_chart) do |index|
            house_power_without_custom_grid(raw_chart, index)
          end,
        house_power_without_custom_pv:
          map_house_power(raw_chart) do |index|
            house_power_without_custom_pv(raw_chart, index)
          end,
      }
    else
      # No data for house_power_grid is present, return simple chart instead
      {
        house_power_without_custom:
          map_house_power(raw_chart) do |index|
            house_power_without_custom(raw_chart, index)
          end,
      }
    end
  end

  def map_house_power(raw_chart)
    return [] unless raw_chart[:house_power]

    raw_chart[:house_power].map.with_index do |(timestamp, _), index|
      [timestamp, yield(index)]
    end
  end

  def house_power_without_custom(raw_chart, index)
    house_power = raw_chart.dig(:house_power, index)&.second
    return unless house_power

    excluded_sensor_names
      .reduce(house_power) do |acc, sensor|
        acc - raw_chart.dig(sensor, index)&.second.to_f
      end
      .clamp(0, nil)
  end

  def house_power_without_custom_grid(raw_chart, index)
    house_power_grid = raw_chart.dig(:house_power_grid, index)&.second
    return unless house_power_grid

    custom_total_grid =
      SensorConfig.x.included_custom_sensor_names.sum do |sensor|
        raw_chart.dig("#{sensor}_grid", index)&.second.to_f
      end

    house_power_without_custom = house_power_without_custom(raw_chart, index)

    (house_power_grid - custom_total_grid).clamp(0, house_power_without_custom)
  end

  def house_power_without_custom_pv(raw_chart, index)
    power = house_power_without_custom(raw_chart, index)
    grid_power = house_power_without_custom_grid(raw_chart, index)
    return unless power && grid_power

    power - grid_power
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
      house_power_without_custom: '#64748b', # bg-slate-500
      house_power_without_custom_grid: '#dc2626', # bg-red-600
      house_power_without_custom_pv: '#16a34a', # bg-green-600
    }[
      chart_sensor,
    ]
  end

  def style(chart_sensor, split:)
    if split
      {
        fill: 'origin',
        # Base color, will be changed to gradient in JS
        backgroundColor: background_color(chart_sensor),
        barPercentage: chart_sensor == :house_power_without_custom ? 0.7 : 1.3,
        categoryPercentage: 0.7,
        borderRadius:
          if chart_sensor == :house_power_without_custom
            { topLeft: 5, bottomLeft: 0, topRight: 0, bottomRight: 0 }
          else
            0
          end,
        borderWidth:
          case chart_sensor # rubocop:disable Style/HashLikeCase
          when :house_power_without_custom
            { top: 1, left: 1 }
          when :house_power_without_custom_grid
            { right: 1 }
          when :house_power_without_custom_pv
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
