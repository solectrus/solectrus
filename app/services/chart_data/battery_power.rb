class ChartData::BatteryPower < ChartData::Base
  private

  def data
    {
      labels:
        labels_for(:battery_charging_power) ||
          labels_for(:battery_discharging_power),
      datasets: [
        dataset(:battery_charging_power),
        dataset(:battery_discharging_power),
      ],
    }
  end

  def labels_for(sensor)
    chart[sensor]&.map { |x| x.first.to_i * 1000 }
  end

  def dataset(sensor)
    {
      label: I18n.t("sensors.#{sensor}"),
      data: mapped_data(chart[sensor], sensor),
    }.merge(style)
  end

  def mapped_data(data, sensor)
    if sensor == :battery_charging_power
      # Take it as is
      data&.map(&:second)
    else
      # Must be negative
      data&.map { |x| x.second ? -x.second : nil }
    end
  end

  def chart
    @chart ||= PowerChart.new(sensors:).call(timeframe, interpolate: true)
  end

  def sensors
    %i[battery_charging_power battery_discharging_power]
  end

  def style
    super.merge(
      backgroundColor: '#15803d', # bg-green-700
    )
  end
end
