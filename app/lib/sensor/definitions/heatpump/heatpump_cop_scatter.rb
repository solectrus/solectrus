class Sensor::Definitions::HeatpumpCopScatter < Sensor::Definitions::Base
  value unit: :unitless, range: (0..), category: :heatpump

  depends_on :heatpump_cop, :outdoor_temp, :heatpump_power

  home_pages :heatpump

  chart do |timeframe|
    Sensor::Chart::HeatpumpCopScatter.new(timeframe:)
  end

  # A scatter of COP against temperature: the chart pairs the two dependencies
  # into points, so the sensor itself carries no value at any single instant.
  chart_only

  requires_permission :heatpump
end
