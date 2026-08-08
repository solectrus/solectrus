class Sensor::Definitions::PowerBalance < Sensor::Definitions::Base
  value unit: :watt, category: :other

  chart do |timeframe|
    Sensor::Chart::PowerBalance.new(timeframe:)
  end

  # Stacked power-flow balance: the chart composes it, there is no value.
  chart_only
end
