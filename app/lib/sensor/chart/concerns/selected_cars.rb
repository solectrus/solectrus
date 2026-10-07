module Sensor
  module Chart
    module Concerns
      # A chart of the car page, which gives the selected cars (see
      # CarSelectable). Without them, the chart shows all cars.
      module SelectedCars
        def initialize(cars: nil, **)
          super(**)
          @cars = cars
        end

        def cars
          @cars ||= Car.configured
        end
      end
    end
  end
end
