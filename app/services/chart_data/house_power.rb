class ChartData::HousePower < ChartData::Base
  private

  def data
    @data ||= {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: SensorConfig.x.name(chart_sensor),
            data: data.map(&:second),
            stack: chart_sensor == :house_power ? nil : 'Power-Splitter',
          }.merge(style(chart_sensor, split: chart.key?(:house_power_grid)))
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

    { house_power: adjusted_house_power(raw_chart, exclude_grid: false) }
  end

  def splitted_chart
    raw_chart =
      PowerChart.new(
        sensors: [:house_power, grid_sensor, *excluded_sensor_names],
      ).call(timeframe)

    result =
      if raw_chart.key?(:house_power) && raw_chart.key?(grid_sensor)
        {
          house_power: adjusted_house_power(raw_chart, exclude_grid: false),
          house_power_grid: raw_chart[grid_sensor],
          house_power_pv: adjusted_house_power(raw_chart, exclude_grid: true),
        }
      else
        # No data for house_power_grid is present, return simple chart instead
        {
          house_power: adjusted_house_power(raw_chart, exclude_grid: false),
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
      excluded_sensor_names,
      (grid_sensor if exclude_grid),
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

  def excluded_sensor_names
    SensorConfig.x.excluded_sensor_names
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

  def style(chart_sensor, split:)
    if split
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
