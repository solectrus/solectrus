class ChartData::CarDrivingDistance < ChartData::Base
  def type
    'bar'
  end

  private

  def data
    {
      labels: chart&.map { |x| x.first.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('sensors.car_driving_distance'),
          data: chart&.map { |x| x.second&.round },
        }.merge(style),
      ],
    }
  end

  def chart
    @chart ||=
      DiffChart
        .new(source_sensor: :car_mileage, target_sensor: :car_driving_distance)
        .call(timeframe)
        &.dig(:car_driving_distance)
  end

  def style
    super.merge(
      backgroundColor: '#a1a1aa', # bg-zinc-400
    )
  end
end
