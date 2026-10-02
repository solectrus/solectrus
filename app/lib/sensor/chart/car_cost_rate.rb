# The cost of driving the car in EUR/100 km, one rate for each bucket.
class Sensor::Chart::CarCostRate < Sensor::Chart::CarRateBase
  def chart_sensor_names
    %i[car_cost_rate]
  end

  private

  def value(totals)
    totals.cost_per_100km
  end
end
