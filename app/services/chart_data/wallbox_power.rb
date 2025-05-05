class ChartData::WallboxPower < ChartData::Base
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
            stack: chart_sensor == :wallbox_power ? nil : 'Power-Splitter',
          }.merge(style(chart_sensor, split: chart.key?(:wallbox_power_grid)))
        end,
    }
  end

  def chart
    @chart ||= splitting_allowed? ? splitted_chart : simple_chart
  end

  def simple_chart
    PowerChart.new(sensors: %i[wallbox_power]).call(timeframe)
  end

  def splitted_chart # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raw_chart =
      PowerChart.new(sensors: %i[wallbox_power wallbox_power_grid]).call(
        timeframe,
      )

    unless raw_chart.key?(:wallbox_power) && raw_chart.key?(:wallbox_power_grid)
      # No data for wallbox_power_grid is present, return simple chart instead
      return raw_chart
    end

    wallbox_power = raw_chart[:wallbox_power]

    wallbox_power_grid =
      wallbox_power.map.with_index do |(timestamp, power), index|
        power_grid = raw_chart.dig(:wallbox_power_grid, index)&.second.to_f
        [timestamp, power ? [power, power_grid].min : nil]
      end

    wallbox_power_pv =
      wallbox_power.map.with_index do |(timestamp, power), index|
        power_grid = raw_chart.dig(:wallbox_power_grid, index)&.second.to_f
        [timestamp, power ? [(power - power_grid), 0].max : nil]
      end

    { wallbox_power:, wallbox_power_grid:, wallbox_power_pv: }
  end

  def background_color(chart_sensor)
    {
      wallbox_power: '#334155', # bg-slate-700
      wallbox_power_grid: '#dc2626', # bg-red-600
      wallbox_power_pv: '#16a34a', # bg-green-600
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
        barPercentage: chart_sensor == :wallbox_power ? 0.7 : 1.3,
        categoryPercentage: 0.7,
        borderRadius:
          if chart_sensor == :wallbox_power
            { topLeft: 5, bottomLeft: 0, topRight: 0, bottomRight: 0 }
          else
            0
          end,
        borderWidth:
          case chart_sensor # rubocop:disable Style/HashLikeCase
          when :wallbox_power
            { top: 1, left: 1 }
          when :wallbox_power_grid
            { right: 1 }
          when :wallbox_power_pv
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

    SensorConfig.x.exists?(:wallbox_power_grid)
  end
end
