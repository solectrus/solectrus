module Sensor
  module Chart
    module Concerns
      # A chart of the car page, which gives the selected cars (see
      # Cars::Selectable). Without them, the chart shows all cars. The guest
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

        # The note of a chart without a drive. A drive can still come in a
        # timeframe that runs, like today.
        def no_driving_message
          I18n.t(timeframe.current? ? 'data.car_no_driving_yet' : 'data.car_no_driving')
        end
      end
    end
  end
end
