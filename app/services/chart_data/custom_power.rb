class ChartData::CustomPower < ChartData::Base
  def initialize(timeframe:, sensor:)
    super(timeframe:)
    @sensor = sensor
    @sensor_grid ||= :"#{sensor}_grid"
    @sensor_pv ||= :"#{sensor}_pv"
  end

  attr_reader :sensor, :sensor_grid, :sensor_pv

  private

  def data
    @data ||= {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: SensorConfig.x.display_name(chart_sensor),
            data: data.map(&:second),
            stack: chart_sensor == sensor ? nil : 'Power-Splitter',
          }.merge(style(chart_sensor, split: chart.key?(sensor_grid)))
        end,
    }
  end

  def chart
    @chart ||= splitting_allowed? ? splitted_chart : simple_chart
  end

  def simple_chart
    PowerChart.new(sensors: [sensor]).call(timeframe)
  end

  def splitted_chart # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raw_chart = PowerChart.new(sensors: [sensor, sensor_grid]).call(timeframe)

    unless raw_chart.key?(sensor) && raw_chart.key?(sensor_grid)
      # No data for custom_power_grid is present, return simple chart instead
      return raw_chart
    end

    custom_power = raw_chart[sensor]

    custom_power_grid =
      custom_power.map.with_index do |(timestamp, power), index|
        power_grid = raw_chart.dig(sensor_grid, index)&.second.to_f
        [timestamp, power ? [power, power_grid].min : nil]
      end

    custom_power_pv =
      custom_power.map.with_index do |(timestamp, power), index|
        power_grid = raw_chart.dig(sensor_grid, index)&.second.to_f
        [timestamp, power ? [(power - power_grid), 0].max : nil]
      end

    {
      sensor => custom_power,
      sensor_grid => custom_power_grid,
      sensor_pv => custom_power_pv,
    }
  end

  def background_color(chart_sensor)
    {
      sensor => '#475569', # bg-slate-600
      sensor_grid => '#dc2626', # bg-red-600
      sensor_pv => '#16a34a', # bg-green-600
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
        barPercentage: chart_sensor == sensor ? 0.7 : 1.3,
        categoryPercentage: 0.7,
        borderRadius:
          if chart_sensor == sensor
            { topLeft: 5, bottomLeft: 0, topRight: 0, bottomRight: 0 }
          else
            0
          end,
        borderWidth:
          case chart_sensor
          when sensor
            { top: 1, left: 1 }
          when sensor_grid
            { right: 1 }
          when sensor_pv
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

  def splitting_allowed?
    # Because data is only available hourly we can't use for line charts
    return false if timeframe.short?

    SensorConfig.x.exists?(sensor_grid)
  end
end
