class Sensor::Definitions::SelfConsumption < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  depends_on :inverter_power, :grid_export_power

  calculate do |inverter_power:, grid_export_power:, **|
    return unless inverter_power && grid_export_power

    inverter_power - grid_export_power
  end
end
