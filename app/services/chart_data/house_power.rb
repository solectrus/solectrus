class ChartData::HousePower < ChartData::Base
  private

  def data
    {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.house_power'),
          data: chart&.map(&:second),
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      if raw_chart[:house_power] && exclude_from_house_power.present?
        adjusted_chart
      else
        raw_chart[:house_power]
      end
  end

  def adjusted_chart
    # Subtract other sensors from house_power
    raw_chart[:house_power].map.with_index do |power, index|
      [
        power.first,
        if power.second
          [
            0,
            exclude_from_house_power.reduce(power.second) do |acc, elem|
              acc - raw_chart.dig(elem, index)&.second.to_f
            end,
          ].max
        end,
      ]
    end
  end

  def raw_chart
    @raw_chart ||=
      PowerChart.new(sensors: [:house_power, *exclude_from_house_power]).call(
        timeframe,
      )
  end

  def exclude_from_house_power
    SensorConfig.x.exclude_from_house_power
  end

  def style
    super.merge(
      backgroundColor: '#64748b', # bg-slate-500
    )
  end
end
