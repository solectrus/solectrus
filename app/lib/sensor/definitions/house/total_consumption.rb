class Sensor::Definitions::TotalConsumption < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  # Neutral gray, shared with house_power: total consumption is dominated by
  # the house and reads as a generic "consumption" baseline in its own chart.
  color background: 'bg-sensor-house',
        text: 'text-white dark:text-slate-400'

  icon 'fa-plug'

  depends_on do
    [
      :house_power,
      (:heatpump_power if Sensor::Config.configured?(:heatpump_power)),
      (:wallbox_power if Sensor::Config.configured?(:wallbox_power)),
    ].compact
  end

  calculate do |house_power:, wallbox_power: nil, heatpump_power: nil, **|
    values = [house_power, wallbox_power, heatpump_power].compact
    # Stay nil (not 0) when no consumer has data, so empty periods render as a
    # gap / "no data" instead of a misleading 0 baseline. A genuine 0 reading
    # from a present sensor is kept.
    values.sum unless values.empty?
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg min max]

  # Lower consumption is the better outcome, so a falling trend reads green.
  trend more_is_better: false

  chart { |timeframe| Sensor::Chart::TotalConsumption.new(timeframe:) }
end
