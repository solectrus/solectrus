module Sensor
  module Chart
    module Concerns
      # A chart of the cars of the car page. Without them, it shows all cars.
      module SelectedCars
        def initialize(cars: nil, **)
          super(**)
          @cars = cars
        end

        def cars
          @cars ||= Car::Provisioning.call.to_a
        end
      end
    end
  end
end
