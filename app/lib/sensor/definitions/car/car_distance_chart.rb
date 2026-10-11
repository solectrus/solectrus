# The distance on the car page: a part for each selected car.
# The values come from car_odometer_<n> (see CarOdometer). The sensor has no
# number, because the car select above the chart selects the cars.
class Sensor::Definitions::CarDistanceChart < Sensor::Definitions::Base
  include Sensor::Definitions::CarRoleChart

  def name = :car_distance

  def car_role = :car_odometer

  value unit: :kilometer, category: :car

  color background: 'bg-sensor-wallbox', text: 'text-white dark:text-slate-400'

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarDistance.new(timeframe:, cars:) }

  # The top 10 ranks the distance of all cars together, from the daily
  # distances of their odometers (see Sensor::Query::Ranking)
  aggregations computed: [:sum], top10: true

  # Less driving is the better outcome, like car_odometer_<n>
  trend

  def storable_fields(_visited = nil) = data_sensors.keys

  def sql_calculation = storable_fields.map { "COALESCE(#{it}_sum, 0)" }.join(' + ')
end
