class ChartData::Autarky < ChartData::Base
  def suggested_max
    100
  end

  private

  def data
    @data ||= {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          id: 'autarky',
          label: I18n.t('calculator.autarky'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||= AutarkyChart.new.call(timeframe)
  end

  def style
    super.merge(
      backgroundColor: '#15803d', # bg-green-700
    )
  end
end
