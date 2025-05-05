class ChartData::BatteryPower < ChartData::Base
  private

  def data
    @data ||= {
      labels:
        labels_for(:battery_charging_power) ||
          labels_for(:battery_discharging_power),
      datasets: [
        (dataset(:battery_charging_power_grid) if splitting_allowed?),
        dataset(:battery_charging_power),
        dataset(:battery_discharging_power),
      ].compact,
    }
  end

  def labels_for(sensor)
    chart[sensor]&.map { |timestamp, _value| timestamp.to_i * 1000 }
  end

  def dataset(sensor)
    {
      id: sensor,
      label: label(sensor),
      data: mapped_data(chart[sensor], sensor),
    }.merge(style(sensor))
  end

  def label(sensor)
    case sensor
    when :battery_charging_power_grid
      "#{SensorConfig.x.display_name(:battery_charging_power)} (#{I18n.t('splitter.grid')})"
    when :battery_charging_power
      if splitting_allowed?
        "#{SensorConfig.x.display_name(:battery_charging_power)} (#{I18n.t('splitter.pv')})"
      else
        SensorConfig.x.display_name(:battery_charging_power)
      end
    when :battery_discharging_power
      SensorConfig.x.display_name(:battery_discharging_power)
    end
  end

  def mapped_data(data, sensor)
    return unless data

    case sensor
    when :battery_charging_power
      splitting_allowed? ? mapped_data_charging_pv : mapped_data_values(data)
    when :battery_charging_power_grid
      mapped_data_values(data)
    when :battery_discharging_power
      mapped_data_discharging(data)
    end
  end

  # Extracts the value from each data point.
  def mapped_data_values(data)
    data.map { |_timestamp, value| value }
  end

  # Converts discharging values to negative.
  def mapped_data_discharging(data)
    data.map { |_timestamp, value| value ? -value : nil }
  end

  # Calculates charging power by PV
  def mapped_data_charging_pv
    total_data = chart[:battery_charging_power] || []
    grid_data = chart[:battery_charging_power_grid] || []

    total_by_timestamp =
      total_data.to_h { |timestamp, value| [timestamp, value] }

    grid_data.map do |timestamp, grid|
      total = total_by_timestamp[timestamp]
      next unless total && grid

      total - grid
    end
  end

  def chart
    @chart ||= PowerChart.new(sensors:).call(timeframe)
  end

  def sensors
    %i[
      battery_charging_power
      battery_discharging_power
      battery_charging_power_grid
    ]
  end

  COLORS = {
    battery_charging_power: '#15803d', # bg-green-700
    battery_discharging_power: '#15803d', # bg-green-700
    battery_charging_power_grid: '#dc2626', # bg-red-600
  }.freeze
  private_constant :COLORS

  def style(sensor)
    super().merge(
      backgroundColor: COLORS[sensor],
      stack: splitting_allowed? ? 'BatteryStack' : nil,
      minBarLength: 0,
    ).compact
  end

  def splitting_allowed?
    # As the data from the PowerSplitter is available in intervals only,
    # we cannot use it for line diagrams.
    return false if timeframe.short?

    SensorConfig.x.exists?(:battery_charging_power_grid) &&
      chart[:battery_charging_power_grid].present?
  end
end
