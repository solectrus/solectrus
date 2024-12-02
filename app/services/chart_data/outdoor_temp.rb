class ChartData::OutdoorTemp < ChartData::Base
  private

  def data
    {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('sensors.outdoor_temp'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      MinMaxChart.new(sensor: :outdoor_temp, average: false).call(timeframe)[
        :outdoor_temp
      ]
  end

  def style
    super.merge(
      backgroundColor: '#2dd4bf', # bg-teal-400
      # In min-max charts, show border around the **whole** bar (don't skip)
      borderSkipped: false,
    )
  end
end
