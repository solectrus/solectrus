class ChartData::WallboxPower < ChartData::Base
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
    PowerChart.new(sensors: %i[wallbox_power]).call(
      timeframe,
      fill: !timeframe.current?,
    )
  end

  def splitted_chart
    chart =
      PowerChart.new(sensors: %i[wallbox_power wallbox_power_grid]).call(
        timeframe,
        fill: !timeframe.current?,
      )

    if chart.key?(:wallbox_power) && chart.key?(:wallbox_power_grid)
      {
        wallbox_power_pv:
          chart[:wallbox_power].map.with_index do |wallbox_power, index|
            # wallbox_power_pv = wallbox_power - wallbox_power_grid
            timestamp, power = wallbox_power
            [
              timestamp,
              if power
                [
                  0,
                  [:wallbox_power_grid].reduce(power) do |acc, elem|
                    acc - chart.dig(elem, index)&.second.to_f
                  end,
                ].max
              end,
            ]
          end,
        wallbox_power_grid: chart[:wallbox_power_grid],
      }
    else
      # No data for wallbox_power_grid is present, return simple chart instead
      chart
    end
  end

  def background_color(chart_sensor)
    {
      wallbox_power: '#334155', # bg-slate-700
      wallbox_power_grid: '#7f1d1d', # bg-red-900
      wallbox_power_pv: '#14532d', # bg-green-900
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
    return false unless SensorConfig.x.exists?(:wallbox_power_grid)

    # Because data is only available hourly we can't use for line charts
    !timeframe.now? && !timeframe.day?
  end
end
