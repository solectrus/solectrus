class ChartData::BatterySoc < ChartData::Base
  def suggested_max
    100
  end

  private

  def data
    @data ||= {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('sensors.battery_soc'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      MinMaxChart.new(sensor: :battery_soc, average: true).call(timeframe)[
        :battery_soc
      ]
  end

  def style
    super.merge(
      backgroundColor: '#38bdf8', # bg-sky-400
      # In min-max charts, show border around the **whole** bar (don't skip)
      borderSkipped: false,
    )
  end
end
