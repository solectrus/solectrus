# The choice of the car in the top 10. The sensor select offers a car sensor
# as its role, and this choice the cars that rank that role, and all cars
# when a sensor ranks the role of all cars. The select of the desktop and the
# options of a phone both offer it.
class Top10::CarChoice
  def initialize(current_sensor)
    @current_sensor = current_sensor
  end

  # Only a car sensor with a choice of cars has a choice
  def offered?
    role.present? && cars.many?
  end

  def cars
    @cars ||= Car.configured.select { sensor_names.include?(it.sensor_name(role)) }
  end

  # The car of the current sensor, or nil for all cars
  def car
    cars.find { it.sensor_name(role) == @current_sensor.name }
  end

  def all?
    all_cars_sensor.present?
  end

  # The sensor of a car, or of all cars for nil
  def sensor_name(car_id)
    car_id ? Sensor::Cars.sensor_name(role, car_id) : all_cars_sensor.name
  end

  private

  def role = @current_sensor.try(:car_role)

  # The sensor of the role without a number ranks all cars together
  def all_cars_sensor
    sensors_of_role.find { it.try(:car_number).nil? }
  end

  def sensor_names = sensors_of_role.map(&:name)

  def sensors_of_role
    @sensors_of_role ||= Sensor::Config.top10_sensors.select { it.try(:car_role) == role }
  end
end
