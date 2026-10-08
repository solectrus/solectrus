module Sensor
  module Definitions
    # A chart of the driving on the car page, like car_cost_rate. The chart
    # builds each column from the window around each day (see
    # Sensor::Chart::CarDriving), so the sensor never carries a scalar value.
    module CarDrivingChart
      extend ActiveSupport::Concern
      include CarPageChart

      included do
        chart { |timeframe, cars: nil, **| Sensor::Chart::CarDriving.new(timeframe:, cars:, metric: name) }
      end

      # A rate needs the distance of a car. The energy and the cost can come
      # from the offsite sessions alone, so the wallbox is no condition.
      def static_dependencies = Sensor::Cars.dependency(:car_odometer)
    end
  end
end
