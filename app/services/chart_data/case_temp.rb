class ChartData::CaseTemp < ChartData::Base
  def suggested_min
    10
  end

  def suggested_max
    40
  end

  private

  def data
    @data ||= {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          id: 'case_temp',
          label: SensorConfig.x.display_name(:case_temp),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      MinMaxChart.new(sensor: :case_temp, average: false).call(timeframe)[
        :case_temp,
      ]
  end

  def style
    super.merge(
      backgroundColor: '#f87171', # bg-red-400
      # In min-max charts, show border around the **whole** bar (don't skip)
      borderSkipped: false,
    )
  end
end
