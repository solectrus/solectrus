class Sensor::Definitions::PowerBalance < Sensor::Definitions::Base
  value unit: :watt, category: :other

  chart do |timeframe|
    Sensor::Chart::PowerBalance.new(timeframe:)
  end

  # Mark as calculated so it can exist without direct configuration.
  # Block must accept the kwargs the framework passes (dependencies + context).
  calculate { |**| nil }
end
