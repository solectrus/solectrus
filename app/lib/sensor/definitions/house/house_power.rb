class Sensor::Definitions::HousePower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :consumer, nameable: true

  color hex: '#64748b',
        bg_classes: 'bg-slate-500 dark:bg-slate-700',
        text_classes: 'text-white dark:text-slate-400'

  icon 'fa-home'

  # For SQL queries: only need house_power (exclusions already applied)
  # For InfluxDB queries: need all excluded sensors for calculation
  depends_on do |context: :unknown|
    if context == :sql
      [:house_power]
    else
      [:house_power, *Sensor::Config.house_power_excluded_sensors.map(&:name)]
    end
  end

  calculate do |house_power:, context: :unknown, **excluded_sensor_values|
    return unless house_power

    # For SQL data, exclusions are already applied in the database
    return house_power if context == :sql

    # For InfluxDB data, apply exclusions
    configured_exclusion_names =
      Sensor::Config.house_power_excluded_sensors.map(&:name)

    excluded_total =
      excluded_sensor_values
        .slice(*configured_exclusion_names)
        .values
        .compact
        .sum

    [house_power - excluded_total, 0].max
  end

  aggregations stored: %i[sum max], top10: true

  chart { |timeframe| Sensor::Chart::HousePower.new(timeframe:) }

  trend

  def summary_meta_aggregations
    calculated? ? [:sum] : %i[sum avg min max]
  end

  def calculated?
    # Only calculated if there are excluded sensors to subtract
    Sensor::Config.house_power_excluded_sensors.any?
  end

  def costs_grid_sensor_name
    :house_costs_grid
  end

  def costs_pv_sensor_name
    :house_costs_pv
  end
end
