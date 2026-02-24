class Sensor::Definitions::SpecificYield < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :inverter

  depends_on :inverter_power

  calculate do |inverter_power:, **|
    return unless inverter_power
    return unless (kwp = UpdateCheck.instance.kwp&.to_f)
    return if kwp.zero?

    inverter_power.fdiv(kwp)
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]
end
