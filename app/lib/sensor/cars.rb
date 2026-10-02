# The cars of an installation. Each car has a number from 1 to MAX. The
# number names its sensors (car_mileage_2 reads INFLUX_SENSOR_CAR_MILEAGE_2)
# and its record in the table cars, so the sensors, the daily values and the
# charging sessions of a number all belong to the same car.
#
# The limit belongs to all cars and not to one of their sensors. Each number
# needs labels in the field_enum of the daily values, so a higher limit is
# one migration. The registry, Sensor::Config and the model Car read it from
# here.
module Sensor::Cars
  MAX = 5
  public_constant :MAX

  # The sensors of a car, each with a variable of its own. car_max_range is
  # calculated from two of them.
  CONFIGURABLE_ROLES = %i[car_battery_soc car_mileage car_range].freeze
  public_constant :CONFIGURABLE_ROLES

  ROLES = [*CONFIGURABLE_ROLES, :car_max_range].freeze
  public_constant :ROLES

  NAME_PATTERN = /\A(#{ROLES.join('|')})_(\d+)\z/
  private_constant :NAME_PATTERN

  # The variable of a car sensor, with the number of the car
  VARIABLE_PATTERN = /\AINFLUX_SENSOR_(?:#{CONFIGURABLE_ROLES.map(&:upcase).join('|')})_(\d+)\z/
  private_constant :VARIABLE_PATTERN

  def self.numbers = (1..MAX)

  # The numbers with a variable for one of their sensors at least. Only
  # such a number can have a car.
  def self.configured_numbers
    numbers.select do |number|
      CONFIGURABLE_ROLES.any? { Sensor::Config.configured?(sensor_name(it, number)) }
    end
  end

  def self.sensor_name(role, number) = :"#{role}_#{number}"

  # The state of charge that the power balance shows beside the house
  # battery: the one of the first car that has one
  def self.balance_soc_sensor_name
    configured_numbers.map { sensor_name(:car_battery_soc, it) }.find { Sensor::Config.exists?(it) }
  end

  # The static dependency of a sensor that needs the odometer of any car:
  # the first configured odometer, or the one of car 1 when there is none,
  # so Sensor::Config#exists? answers false.
  def self.odometer_dependency
    number = configured_numbers.find { Sensor::Config.configured?(sensor_name(:car_mileage, it)) }

    [sensor_name(:car_mileage, number || 1)]
  end

  # The number of a car sensor, or nil for any other sensor
  def self.number_of(sensor_name)
    sensor_name.to_s[NAME_PATTERN, 2]&.to_i
  end

  # The role of a car sensor (:car_mileage for car_mileage_2), or nil
  def self.role_of(sensor_name)
    sensor_name.to_s[NAME_PATTERN, 1]&.to_sym
  end

  # The variables of a car above MAX, for the log of Sensor::Config. The
  # registry makes no sensor above MAX, so without a warning such a car is
  # invisible and the user has no hint. Two cars that read the same field
  # get the warning of each duplicate configuration.
  def self.config_warnings(env)
    env.filter_map do |name, value|
      number = name[VARIABLE_PATTERN, 1]&.to_i
      next if number.nil? || value.blank? || numbers.cover?(number)

      "#{name} is ignored, the number of a car must be between 1 and #{MAX}"
    end
  end
end
