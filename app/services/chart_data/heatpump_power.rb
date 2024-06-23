class ChartData::HeatpumpPower < ChartData::Base
  private

  def data
    {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('sensors.heatpump_power'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: %i[heatpump_power]).call(
        timeframe,
        fill: !timeframe.current?,
      )[
        :heatpump_power
      ]
  end

  def style
    super.merge(
      backgroundColor: '#475569', # bg-slate-600
    )
  end
end
