class ChartData::InverterPower < ChartData::Base
  private

  def data
    @data ||= with_forecast? ? data_with_forecast : data_simple
  end

  def data_simple
    {
      labels: labels_for(:inverter_power),
      datasets: [dataset(:inverter_power)],
    }
  end

  def data_with_forecast
    {
      labels:
        labels_for(:inverter_power) || labels_for(:inverter_power_forecast),
      datasets: [dataset(:inverter_power), dataset(:inverter_power_forecast)],
    }
  end

  def labels_for(sensor_name)
    chart[sensor_name]&.map { |x| x.first.to_i * 1000 }
  end

  def dataset(sensor_name)
    {
      label: SensorConfig.x.display_name(sensor_name),
      data: chart[sensor_name]&.map { |_, v| v&.negative? ? 0 : v },
    }.merge(style(sensor_name))
  end

  def chart
    # Interpolation required because the forecast data has a lower resolution
    @chart ||= PowerChart.new(sensors:).call(timeframe, interpolate: true)
  end

  def sensors
    if timeframe.day?
      %i[inverter_power inverter_power_forecast]
    else
      [:inverter_power]
    end
  end

  def style(sensor_name)
    background_color =
      case sensor_name
      when :inverter_power
        '#16a34a' # bg-green-600
      when :inverter_power_forecast
        '#cbd5e1' # bg-slate-300
      end

    super().merge(backgroundColor: background_color)
  end

  def with_forecast?
    timeframe.day? && !SensorConfig.x.exists?(:balcony_inverter_power)
  end
end
