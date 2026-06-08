class Sensor::Definitions::TotalConsumption < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  # Neutral gray, shared with house_power: total consumption is dominated by
  # the house and reads as a generic "consumption" baseline in its own chart.
  color background: 'bg-sensor-house',
        text: 'text-white dark:text-slate-400'

  icon 'fa-plug'

  # Custom consumers excluded from house_power are subtracted from house_power
  # (both the live InfluxDB value and the stored summary value, which is built
  # from the same InfluxDB calculation). Add them back here so total_consumption
  # stays a true sum of all consumption instead of dropping the excluded ones.
  depends_on do
    [
      :house_power,
      (:heatpump_power if Sensor::Config.configured?(:heatpump_power)),
      (:wallbox_power if Sensor::Config.configured?(:wallbox_power)),
      *excluded_custom_sensor_names,
    ].compact
  end

  calculate do |house_power:, wallbox_power: nil, heatpump_power: nil, **rest|
    excluded_custom_values =
      excluded_custom_sensor_names.filter_map { |name| rest[name] }

    values =
      [house_power, wallbox_power, heatpump_power, *excluded_custom_values].compact
    # Stay nil (not 0) when no consumer has data, so empty periods render as a
    # gap / "no data" instead of a misleading 0 baseline. A genuine 0 reading
    # from a present sensor is kept.
    values.sum unless values.empty?
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg min max]

  # Lower consumption is the better outcome, so a falling trend reads green.
  trend more_is_better: false

  chart { |timeframe| Sensor::Chart::TotalConsumption.new(timeframe:) }

  private

  def excluded_custom_sensor_names
    Sensor::Config.house_power_excluded_custom_sensors.map(&:name)
  end
end
