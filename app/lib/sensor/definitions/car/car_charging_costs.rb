class Sensor::Definitions::CarChargingCosts < Sensor::Definitions::Base
  include Sensor::Definitions::CarPageChart

  value unit: :money, category: :economic

  # The charging cost of the sessions, like the charged energy (see
  # Sensor::Definitions::CarCharging)
  chart do |timeframe, cars: nil, guest: false, **|
    Sensor::Chart::CarSessions.new(timeframe:, cars:, guest:, measure: :cost) unless timeframe.short?
  end

  trend
end
