# The places of the selected cars on a map. It comes from car_latitude_<n>
# and car_longitude_<n> (see Sensor::Chart::CarLocation).
class Sensor::Definitions::CarLocationChart < Sensor::Definitions::Base
  include Sensor::Definitions::CarPageChart

  def name = :car_location

  value unit: :unitless, category: :car

  icon 'location-dot'

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarLocation.new(timeframe:, cars:) }

  def static_dependencies = Sensor::Cars.dependency(:car_latitude, :car_longitude)

  personal
end
