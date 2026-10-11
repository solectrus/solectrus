module Sensor
  module Chart
    module Concerns
      # A chart of the car page, which gives the selected cars (see
      # CarSelectable). Without them, the chart shows all cars. The guest
      # sessions (`guest: true`) have no car.
      module SelectedCars
        def initialize(cars: nil, guest: false, **)
          super(**)
          @cars = cars
          @guest = guest
        end

        def cars
          @cars ||= Car.configured
        end

        def guest? = @guest
      end
    end
  end
end
