class CarChartDropdown::Component < ViewComponent::Base
  include ChartDropdownLogic

  # The order of the menu, by the sensor without its number. A sensor the
  # list does not know goes to the end, so a new one shows up instead of
  # disappearing.
  ORDER = %i[
    car_charging
    car_charging_costs
    car_driving_costs
    car_consumption_rate
    car_cost_rate
    car_mileage
    car_battery_soc
    car_range
    car_max_range
  ].freeze
  private_constant :ORDER

  # The titles of the tiles that link to the charts
  TITLES = {
    car_charging: 'sensors.car_charged_short',
    car_mileage: 'sensors.car_mileage_short',
    car_battery_soc: 'sensors.car_battery_soc_short',
    car_range: 'sensors.car_range_short',
    car_max_range: 'sensors.car_max_range_short',
  }.freeze
  private_constant :TITLES

  def initialize(sensor_name:, timeframe:, cars:)
    super(sensor_name:, timeframe:)
    @cars = cars
  end

  attr_reader :cars

  def call
    render_chart_selector
  end

  private

  def page_key = :cars

  def menu_items
    @menu_items ||= offered.sort_by { [ORDER.index(role(it)) || ORDER.size, Sensor::Cars.number_of(it).to_i] }
  end

  # A rate chart needs buckets of a day at least, and the range chart draws a
  # day at most, so a timeframe offers only the charts it supports. The
  # sensors of a car belong to the selected car. The selection "all" offers
  # the sensors of each car, and the distance one time, because its chart
  # shows each car (see Sensor::Chart::CarMileage).
  def offered
    names = sensor_names.select { selected?(it) && Sensor::Registry[it].chart(timeframe, cars:).supported? }
    first_distance = names.find { role(it) == :car_mileage }
    names.reject { role(it) == :car_mileage && it != first_distance }
  end

  def selected?(name)
    number = Sensor::Cars.number_of(name)
    number.nil? || cars.any? { it.id == number }
  end

  def role(name) = Sensor::Cars.role_of(name) || name

  # One car needs no name in the menu. The selection "all" names the car of
  # each sensor, except for the distance, which shows each car.
  def menu_config
    super.merge(grouped: false, display_names: menu_items.index_with { title(it) }.compact)
  end

  def title(name)
    key = TITLES[role(name)]
    return unless key
    return I18n.t(key) if cars.one? || role(name) == :car_mileage || Sensor::Cars.number_of(name).nil?

    Sensor::Registry[name].display_name
  end
end
