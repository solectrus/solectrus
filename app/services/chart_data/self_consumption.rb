class ChartData::SelfConsumption < ChartData::Base
  private

  def data
    {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.self_consumption_quote'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||= ConsumptionChart.new.call(timeframe)
  end

  def style
    super.merge(
      backgroundColor: '#15803d', # bg-green-700
    )
  end
end
