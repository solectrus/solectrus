module Sensor
  module Definitions
    # The chart of a car role on the car page, like car_battery_soc. It reads
    # the sensors of the selected cars, so each car has its own sensor with
    # the data: car_battery_soc_1, car_battery_soc_2 (see Sensor::Cars).
    module CarRoleChart
      extend ActiveSupport::Concern
      include CarPageChart

      # The role of the sensors with the data. A chart named after another
      # quantity than its role overrides it, like car_distance.
      def car_role = name

      # The sensors of the configured cars with the role, each with the name
      # of its car
      def data_sensors
        Sensor::Cars.numbered(car_role).index_with { Car.display_name_of(Sensor::Cars.number_of(it)) }
      end

      # A chart that needs more sensors than its role overrides it
      def static_dependencies = Sensor::Cars.dependency(car_role)
    end
  end
end
