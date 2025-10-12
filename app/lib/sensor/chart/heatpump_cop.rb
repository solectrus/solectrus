class Sensor::Chart::HeatpumpCop < Sensor::Chart::Base
  def chart_sensor_names
    %i[heatpump_cop heatpump_heating_power]
  end

  def suggested_max
    data[:datasets].first[:data].compact.max
  end

  def datasets(chart_data_items)
    cop_data =
      chart_data_items.find { |item| item[:sensor_name] == :heatpump_cop }
    heating_data =
      chart_data_items.find do |item|
        item[:sensor_name] == :heatpump_heating_power
      end

    return [] unless cop_data

    [
      {
        **style_for_sensor(cop_sensor),
        id: cop_sensor.name,
        label: cop_sensor.display_name,
        data: cop_data[:data],
        backgroundColor:
          background_colors_with_opacity(
            cop_data[:data],
            heating_data&.dig(:data),
          ),
      },
    ]
  end

  private

  def cop_sensor
    Sensor::Registry[:heatpump_cop]
  end

  def background_colors_with_opacity(cop_values, heating_values)
    unless heating_values
      return Array.new(cop_values.length, default_background_color)
    end

    # Find max heating power for normalization using global max
    max_heating = global_max_heating_power
    unless max_heating&.positive?
      return Array.new(cop_values.length, default_background_color)
    end

    zipped_values = cop_values.zip(heating_values)
    zipped_values.map do |_cop, heating|
      opacity_for_heating_power(heating, max_heating)
    end
  end

  def global_max_heating_power
    @global_max_heating_power ||=
      begin
        ranking =
          Sensor::Query::Ranking.new(
            :heatpump_heating_power,
            aggregation: :sum,
            period: sql_grouping_period,
            desc: true,
            limit: 1,
          )
        ranking.call.first&.dig(:value)
      end
  end

  def opacity_for_heating_power(heating_power, max_heating)
    base_color = cop_sensor.color_hex

    if heating_power.nil? || heating_power <= 0
      return rgba_color(base_color, 0.1)
    end

    # Calculate opacity based on heating power (0.1 to 0.8 range)
    normalized = heating_power.to_f / max_heating
    opacity = (normalized * 0.7) + 0.3

    rgba_color(base_color, opacity)
  end

  def rgba_color(hex_color, opacity)
    # Convert hex color to RGBA with opacity
    hex = hex_color.delete('#')
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    "rgba(#{r}, #{g}, #{b}, #{opacity.round(2)})"
  end

  def default_background_color
    rgba_color(cop_sensor.color_hex, 0.3)
  end
end
