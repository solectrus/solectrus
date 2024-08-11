class ChartData::HeatpumpPower < ChartData::Base
  private

  def data
    {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: I18n.t("sensors.#{chart_sensor}"),
            data: data.map(&:second),
            stack: chart_sensor == :heatpump_power ? nil : 'Power-Splitter',
          }.merge(style(chart_sensor))
        end,
    }
  end

  def chart
    @chart ||= splitted_chart? ? splitted_chart : simple_chart
  end

  def simple_chart
    PowerChart.new(sensors: %i[heatpump_power]).call(
      timeframe,
      fill: !timeframe.current?,
    )
  end

  def splitted_chart
    chart =
      PowerChart.new(sensors: %i[heatpump_power heatpump_power_grid]).call(
        timeframe,
        fill: !timeframe.current?,
      )

    if chart.key?(:heatpump_power) && chart.key?(:heatpump_power_grid)
      {
        heatpump_power: chart[:heatpump_power],
        heatpump_power_grid: chart[:heatpump_power_grid],
        heatpump_power_pv:
          chart[:heatpump_power].map.with_index do |heatpump_power, index|
            # heatpump_power_pv = heatpump_power - heatpump_power_grid
            timestamp, power = heatpump_power
            [
              timestamp,
              if power
                [
                  0,
                  [:heatpump_power_grid].reduce(power) do |acc, elem|
                    acc - chart.dig(elem, index)&.second.to_f
                  end,
                ].max
              end,
            ]
          end,
      }
    else
      # No data for heatpump_power_grid is present, return simple chart instead
      chart
    end
  end

  def background_color(chart_sensor)
    {
      heatpump_power: '#475569', # bg-slate-600
      heatpump_power_grid: '#dc2626', # bg-red-600
      heatpump_power_pv: '#16a34a', # bg-green-600
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
        barPercentage: chart_sensor == :heatpump_power ? 0.7 : 1.3,
        categoryPercentage: 0.7,
        borderRadius:
          if chart_sensor == :heatpump_power
            { topLeft: 5, bottomLeft: 0, topRight: 0, bottomRight: 0 }
          else
            0
          end,
        borderWidth:
          case chart_sensor # rubocop:disable Style/HashLikeCase
          when :heatpump_power
            { top: 1, left: 1 }
          when :heatpump_power_grid
            { right: 1 }
          when :heatpump_power_pv
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
    return false unless SensorConfig.x.exists?(:heatpump_power_grid)

    # Because data is only available hourly we can't use for line charts
    !timeframe.now? && !timeframe.day?
  end
end
