class ChartData::GridPower < ChartData::Base
  private

  def data
    @data ||= {
      labels: labels_for(:grid_import_power) || labels_for(:grid_export_power),
      datasets: [dataset(:grid_import_power), dataset(:grid_export_power)],
    }
  end

  def labels_for(sensor)
    chart[sensor]&.map { |x| x.first.to_i * 1000 }
  end

  def dataset(sensor)
    {
      id: sensor,
      label: SensorConfig.x.display_name(sensor),
      data: mapped_data(chart[sensor], sensor),
    }.merge(style(sensor))
  end

  def mapped_data(data, sensor)
    if sensor == :grid_export_power
      # Take it as is
      data&.map(&:second)
    else
      # Must be negative
      data&.map { |x| x.second ? -x.second : nil }
    end
  end

  def chart
    @chart ||= PowerChart.new(sensors:).call(timeframe)
  end

  def sensors
    %i[grid_import_power grid_export_power]
  end

  def style(sensor)
    background_color =
      case sensor
      when :grid_import_power
        '#dc2626' # bg-red-600
      when :grid_export_power
        '#16a34a' # bg-green-600
      end

    super().merge(backgroundColor: background_color)
  end
end
