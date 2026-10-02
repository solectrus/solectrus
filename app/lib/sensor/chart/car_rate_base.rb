# Base of the two rate charts of the car page, kWh/100 km and EUR/100 km. A
# column is the rate of its days (see Sensor::Chart::CarDailyRatesBase).
class Sensor::Chart::CarRateBase < Sensor::Chart::CarDailyRatesBase
  # A rate has the fixed precision of its unit: 18.4 kWh/100 km, 2.53 EUR/100 km
  def decimals
    chart_sensors.first.exact_precision
  end
end
