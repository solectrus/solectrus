class Sensor::Definitions::SelfConsumption < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  depends_on :inverter_power, :grid_export_power

  calculate do |inverter_power:, grid_export_power:, **|
    return unless inverter_power && grid_export_power

    # Self-consumed PV = generation minus what was exported to the grid.
    # Clamp at >= 0: you cannot self-consume more than you generate.
    [inverter_power - grid_export_power, 0].max
  end

  # Declare a natural (summed) aggregation so this derived sensor is queryable
  # on its own, instead of only being materialized as a side effect of
  # self_consumption_quote. Not stored in the summary table; computed in Ruby
  # from its dependencies' sums.
  aggregations stored: false, computed: [:sum], meta: [:sum]
end
