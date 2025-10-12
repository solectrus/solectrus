class Sensor::Definitions::TotalConsumption < Sensor::Definitions::Base
  value unit: :watt

  depends_on :house_power, :wallbox_power, :heatpump_power

  calculate do |house_power:, wallbox_power:, heatpump_power:, **|
    [house_power, wallbox_power, heatpump_power].compact.sum
  end

  aggregations stored: false, computed: [:sum], meta: %i[sum avg min max]
end
