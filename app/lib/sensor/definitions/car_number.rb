module Sensor
  module Definitions
    # A sensor of one car. The registry makes a definition for each number up
    # to MAX, and the number becomes part of the name: car_odometer_2.
    # Sensor::Config prunes a number without a configuration. Such a sensor
    # holds the data and has no chart: the car page shows the chart of a role
    # for the selected cars (see CarBatterySocChart).
    module CarNumber
      MAX = Sensor::Cars::MAX
      public_constant :MAX

      def initialize(car_number)
        @car_number = car_number
        super()
      end

      attr_reader :car_number

      # The sensor without its number, for example :car_odometer
      def car_role
        self.class.name.demodulize.underscore.to_sym
      end

      def name
        @name ||= Sensor::Cars.sensor_name(car_role, car_number)
      end

      # The name of the car plus the role: "Model Y (SOC)". A car without a
      # name gets the default of I18n: "Car 2: Odometer".
      def display_name(_format = :long)
        role = I18n.t("sensors.car_roles.#{car_role}")
        car_name = Car.name_of(car_number)
        return I18n.t('sensors.car_sensor.unnamed', number: car_number, role:) unless car_name

        I18n.t('sensors.car_sensor.named', car: car_name, role:)
      end

      # A car records only in its period of use. Without a record of the car,
      # because its table is missing, each day counts.
      def recorded_on?(date)
        car = Car.configured.find { it.id == car_number }
        car.nil? || car.active_on?(date)
      end

      def user_defined_name?
        Car.name_of(car_number).present?
      end

      def description
        I18n.t(
          'sensor_descriptions.derived.car',
          description: I18n.t("sensor_descriptions.#{car_role}"),
          car: Car.display_name_of(car_number),
        )
      end
    end
  end
end
