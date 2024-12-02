class ChartData::HeatpumpCop < ChartData::Base
  private

  def data
    {
      labels: combined_chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.heatpump_cop'),
          data: combined_chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def combined_chart
    @combined_chart ||=
      chart_heatpump_power.map.with_index do |item, index|
        heatpump_power = item.second
        heatpump_heating_power = chart_heatpump_heating_power[index].second

        time = item.first
        if heatpump_power&.nonzero? && heatpump_heating_power
          [time, heatpump_heating_power.fdiv(heatpump_power).round(1)]
        else
          [time, nil]
        end
      end
  end

  def chart_heatpump_power
    @chart_heatpump_power ||= chart[:heatpump_power]
  end

  def chart_heatpump_heating_power
    @chart_heatpump_heating_power ||= chart[:heatpump_heating_power]
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
