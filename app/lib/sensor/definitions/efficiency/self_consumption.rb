class Sensor::Definitions::SelfConsumption < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  depends_on :inverter_power, :grid_export_power

  calculate do |inverter_power:, grid_export_power:, **|
    return unless inverter_power && grid_export_power

    # Self-consumed PV = generation minus what was exported to the grid. You
    # cannot self-consume more than you generate, and that is what the declared
    # range says - no floor of its own here.
    inverter_power - grid_export_power
  end

  # Declare a natural (summed) aggregation so this derived sensor is queryable
  # on its own, instead of only being materialized as a side effect of
  # self_consumption_quote. Not stored in the summary table; computed in Ruby
  # from its dependencies' sums.
  aggregations stored: false, computed: [:sum], meta: [:sum]
end
