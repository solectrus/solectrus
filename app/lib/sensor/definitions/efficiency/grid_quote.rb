class Sensor::Definitions::GridQuote < Sensor::Definitions::Base
  value unit: :percent

  depends_on :total_consumption, :grid_import_power, :inverter_power

  calculate do |total_consumption:, grid_import_power:, inverter_power:, **|
    return unless total_consumption && grid_import_power

    if total_consumption.zero?
      return unless inverter_power
      return 0 if inverter_power >= 50 # producing without consumption

      return # no consumption and no production
    end

    (grid_import_power * 100.0 / total_consumption).clamp(0, 100)
  end

  aggregations stored: false, computed: [:avg], meta: [:avg]
end
