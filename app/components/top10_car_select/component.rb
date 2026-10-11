# The select of the car next to the sensor select of the top 10. The sensor
# select offers a car sensor as its role, this select the cars that rank
# that role, and all cars when a sensor ranks the role of all cars. A choice
# keeps the role, the period, the calc and the sort.
class Top10CarSelect::Component < ViewComponent::Base
  BUTTON_CLASS = 'bg-gray-200 hover:bg-white dark:bg-gray-400 dark:hover:bg-gray-300 dark:text-gray-800'.freeze
  private_constant :BUTTON_CLASS

  def initialize(current_sensor:, permitted_params:)
    super()
    @current_sensor = current_sensor
    @permitted_params = permitted_params
  end

  attr_reader :current_sensor, :permitted_params

  # Only a car sensor with a choice of cars needs the select
  def render?
    role.present? && cars.many?
  end

  def call
    render Car::Select::Component.new(
      cars:,
      car: cars.find { it.sensor_name(role) == current_sensor.name },
      path: ->(id) { path(id) },
      all: all_cars_sensor.present?,
      button_class: BUTTON_CLASS,
    )
  end

  private

  def role = current_sensor.try(:car_role)

  def cars
    @cars ||= Car.configured.select { sensor_names.include?(it.sensor_name(role)) }
  end

  # The sensor of the role without a number ranks all cars together
  def all_cars_sensor
    sensors_of_role.find { it.try(:car_number).nil? }
  end

  def path(car_id)
    sensor_name = car_id ? Sensor::Cars.sensor_name(role, car_id) : all_cars_sensor.name
    helpers.url_for(**permitted_params, sensor_name:, only_path: true)
  end

  def sensor_names = sensors_of_role.map(&:name)

  def sensors_of_role
    @sensors_of_role ||= Sensor::Config.top10_sensors.select { it.try(:car_role) == role }
  end
end
