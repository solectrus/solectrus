class ChartData::WallboxPower < ChartData::Base
  private

  def data
    {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('sensors.wallbox_power'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: %i[wallbox_power]).call(timeframe)[:wallbox_power]
  end

  def style
    super.merge(
      backgroundColor: '#334155', # bg-slate-700
    )
  end
end
