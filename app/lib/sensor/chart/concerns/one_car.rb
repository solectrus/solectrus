module Sensor
  module Chart
    module Concerns
      # A chart of a sensor of one car, for example its state of charge. The
      # car page gives its cars (see CarSelectable). The chart needs exactly
      # one of them, because the values of two cars do not add up, and the
      # select above the chart selects the car.
      module OneCar
        include SelectedCars

        def car
          cars.sole if cars.one?
        end

        # A car without the sensor has no chart, so the menu does not offer
        # an empty one
        def supported?
          super && car.present? && chart_sensor_names.all? { Sensor::Config.exists?(it) }
        end

        private

        # The sensor of the car with the given role, for #chart_sensor_names
        def sensor_names_of(role)
          car ? [car.sensor_name(role)] : []
        end

        # A short timeframe reads InfluxDB directly, so the chart leaves out a
        # car outside its period of use here. A longer timeframe reads the
        # daily values, which hold no value outside it (see Sensor::Summarizer).
        def build_data
          super if in_period?
        end

        def in_period?
          !timeframe.short? || car.active_during?(timeframe.beginning.to_date..timeframe.ending.to_date)
        end
      end
    end
  end
end
