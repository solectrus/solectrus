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
        heatpump_power_grid: chart[:heatpump_power_grid],
      }
    else
      # No data for heatpump_power_grid is present, return simple chart instead
      chart
    end
  end

  def background_color(chart_sensor)
    {
      heatpump_power: '#475569', # bg-slate-600
      heatpump_power_grid: '#7f1d1d', # bg-red-900
      heatpump_power_pv: '#14532d', # bg-green-900
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
    return false unless SensorConfig.x.exists?(:heatpump_power_grid)

    # Because data is only available hourly we can't use for line charts
    !timeframe.now? && !timeframe.day?
  end
end
