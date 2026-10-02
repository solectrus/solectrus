module Sensor
  module Chart
    module Concerns
      # A chart of a sensor of one car, for example car_range_2
      module CarNumber
        def initialize(car_number:, **)
          super(**)
          @car_number = car_number
        end

        attr_reader :car_number
      end
    end
  end
end
