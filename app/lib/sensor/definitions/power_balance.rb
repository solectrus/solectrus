class Sensor::Definitions::PowerBalance < Sensor::Definitions::Base
  value unit: :watt, category: :other

  chart do |timeframe|
    Sensor::Chart::PowerBalance.new(timeframe:)
  end

  # Mark as calculated so it can exist without direct configuration.
  calculate { nil }
end
