class Sensor::Chart::GridPower < Sensor::Chart::Base
  private

  def chart_sensor_names
    %i[grid_export_power grid_import_power]
  end

  # Transform import data to negative values
  def transform_data(data, sensor_name)
    case sensor_name
    when :grid_import_power
      data.map { |value| -value if value } # Make import negative
    else
      data # Export stays positive
    end
  end
end
