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
        # Send opacities array for JS to apply with color-mix
        opacities: opacities_for_heating(cop_data[:data], heating_data&.dig(:data)),
      },
    ]
  end

  private

  def cop_sensor
    Sensor::Registry[:heatpump_cop]
  end

  def opacities_for_heating(cop_values, heating_values)
    return Array.new(cop_values.length, 0.3) unless heating_values

    max_heating = global_max_heating_power
    return Array.new(cop_values.length, 0.3) unless max_heating&.positive?

    pairs = cop_values.zip(heating_values)
    pairs.map! { |_cop, heating| opacity_for_heating_power(heating, max_heating) }
    pairs
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
    return 0.1 if heating_power.nil? || heating_power <= 0

    # Calculate opacity based on heating power (0.3 to 1.0 range)
    normalized = heating_power.to_f / max_heating
    ((normalized * 0.7) + 0.3).round(2)
  end
end
