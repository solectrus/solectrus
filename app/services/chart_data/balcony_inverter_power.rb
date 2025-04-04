class ChartData::BalconyInverterPower < ChartData::Base
  private

  def data
    @data ||= {
      labels: labels_for(:balcony_inverter_power),
      datasets: [dataset(:balcony_inverter_power)],
    }
  end

  def labels_for(sensor_name)
    chart[sensor_name]&.map { |x| x.first.to_i * 1000 }
  end

  def dataset(sensor_name)
    {
      label: SensorConfig.x.name(sensor_name),
      data: chart[sensor_name]&.map { |_, v| v&.negative? ? 0 : v },
    }.merge(style)
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: [:balcony_inverter_power]).call(timeframe)
  end

  def style
    background_color = '#16a34a' # bg-green-600

    super.merge(backgroundColor: background_color)
  end
end
