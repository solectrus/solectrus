class Sensor::Definitions::TotalConsumption < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  depends_on do
    [
      :house_power,
      (:heatpump_power if Sensor::Config.configured?(:heatpump_power)),
      (:wallbox_power if Sensor::Config.configured?(:wallbox_power)),
    ].compact
  end

  calculate do |house_power:, wallbox_power: nil, heatpump_power: nil, **|
    [house_power, wallbox_power, heatpump_power].compact.sum
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg min max]
end
