# Base of the two rate charts of the car page, kWh/100 km and EUR/100 km. A
# column is the rate of its days (see Sensor::Chart::Concerns::CarDailyRates).
class Sensor::Chart::CarRateBase < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarDailyRates

  # A rate of an hour means nothing, so a bucket must be a day at least.
  def self.supports?(timeframe)
    !timeframe.short?
  end

  # A rate has the fixed precision of its unit: 18.4 kWh/100 km, 2.53 EUR/100 km
  def decimals
    chart_sensors.first.exact_precision
  end

  private

  def build_data
    build_bucket_data if supported?
  end
end
