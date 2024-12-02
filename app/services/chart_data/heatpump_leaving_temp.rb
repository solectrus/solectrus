class ChartData::HeatpumpLeavingTemp < ChartData::Base
  private

  def data
    {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('sensors.heatpump_leaving_temp'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      MinMaxChart.new(sensor: :heatpump_leaving_temp, average: false).call(
        timeframe,
      )[
        :heatpump_leaving_temp
      ]
  end

  def style
    super.merge(
      backgroundColor: '#f97316', # bg-orange-500
      # In min-max charts, show border around the **whole** bar (don't skip)
      borderSkipped: false,
    )
  end
end
