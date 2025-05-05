class ChartData::Co2Reduction < ChartData::Base
  private

  def data
    @data ||= {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.co2_reduction'),
          data:
            chart&.map do |x|
              (x.second * co2_reduction_factor).round if x.second
            end,
        }.merge(style),
      ],
    }
  end

  def co2_reduction_factor
    Rails.application.config.x.co2_emission_factor.fdiv(
      if timeframe.short?
        # g per hour
        24.0
      else
        # kg
        1000.0
      end,
    )
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: %i[inverter_power]).call(timeframe)[
        :inverter_power,
      ]
  end

  def style
    super.merge(
      backgroundColor: '#0369a1', # bg-sky-700
    )
  end
end
