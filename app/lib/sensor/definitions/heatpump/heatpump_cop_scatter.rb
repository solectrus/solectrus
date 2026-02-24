class Sensor::Definitions::HeatpumpCopScatter < Sensor::Definitions::Base
  value unit: :unitless, range: (0..), category: :heatpump

  depends_on :heatpump_cop, :outdoor_temp, :heatpump_power

  chart do |timeframe|
    Sensor::Chart::HeatpumpCopScatter.new(timeframe:)
  end

  # Chart-only sensor without a stored value.
  calculate { nil }

  requires_permission :heatpump
end
