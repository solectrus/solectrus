class ChartData::HeatpumpCop < ChartData::Base
  def suggested_max
    data[:datasets].first[:data].compact.max
  end

  def type
    if timeframe.short? || (timeframe.days_passed > 300 && timeframe.days?)
      'line'
    else
      'bar'
    end
  end

  private

  def data
    {
      labels: combined_chart.map { |time, _| time.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.heatpump_cop'),
          data: combined_chart.map { |_, cop| cop },
        }.merge(style),
      ],
    }
  end

  def combined_chart
    @combined_chart ||=
      chart_heatpump_power.map.with_index do |(time, power), index|
        heating = chart_heatpump_heating_power[index]&.second
        cop = heating&.fdiv(power) if power&.nonzero?

        [time, cop]
      end
  end

  def chart_heatpump_power
    @chart_heatpump_power ||= chart[:heatpump_power] || []
  end

  def chart_heatpump_heating_power
    @chart_heatpump_heating_power ||= chart[:heatpump_heating_power] || []
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: %i[heatpump_power heatpump_heating_power]).call(
        timeframe,
      )
  end

  def style
    super.merge(
      backgroundColor: '#0369a1', # bg-sky-700
    )
  end
end
