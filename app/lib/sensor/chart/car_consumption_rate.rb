# The consumption of the car in kWh/100 km, one rate for each bucket.
class Sensor::Chart::CarConsumptionRate < Sensor::Chart::CarRateBase
  def chart_sensor_names
    %i[car_consumption_rate]
  end

  private

  def value(totals)
    totals.consumption_per_100km
  end
end
