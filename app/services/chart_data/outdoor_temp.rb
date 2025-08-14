class ChartData::OutdoorTemp < ChartData::Base
  def suggested_min
    0
  end

  def suggested_max
    data[:datasets].first[:data].compact.max
  end

  private

  def data
    @data ||= {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          id: 'outdoor_temp',
          label: SensorConfig.x.display_name(:outdoor_temp),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      MinMaxChart.new(sensor: :outdoor_temp).call(timeframe)[:outdoor_temp]
  end

  def style
    super.merge(
      backgroundColor: '#f87171', # bg-red-400
      # In min-max charts, show border around the **whole** bar (don't skip)
      borderSkipped: false,
    )
  end
end
