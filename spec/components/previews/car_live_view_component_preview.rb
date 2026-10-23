# @label Car live view
# @logical_path data_visualization
# @display max_width 64rem
class CarLiveViewComponentPreview < ViewComponent::Preview
  # Car::Live with fixed values instead of the latest values of InfluxDB
  class Live < Car::Live
    # Fixed distances of a percentage point instead of Car::RangeEstimate
    Estimate = Data.define(:estimates) { def km_per_percent(car) = estimates[car.id] }
    private_constant :Estimate

    def initialize(cars, data, estimates: {})
      super(cars, home: nil)
      @data = Sensor::Data::Single.new(data, timeframe: Timeframe.now, times: data.transform_values { Time.current })
      @estimates = estimates
    end

    attr_reader :data

    private

    def range_estimate = Estimate.new(@estimates)
  end

  # One car, which charges at the wallbox
  def one_car
    live_view(
      [car(1)],
      car_battery_soc_1: 83,
      car_range_1: 273,
      car_max_range_1: 329,
      car_odometer_1: 64_840,
      car_connected_1: true,
      car_latitude_1: 50.9226,
      car_longitude_1: 6.4071,
      wallbox_power: 7_400,
      wallbox_car_connected: true,
    )
  end

  # Two cars: the first charges at the wallbox, the second shows zero next
  # to its plug
  def two_cars
    live_view(
      [car(1), car(2)],
      car_battery_soc_1: 45,
      car_range_1: 190,
      car_max_range_1: 420,
      car_odometer_1: 23_456,
      car_connected_1: true,
      car_latitude_1: 50.9226,
      car_longitude_1: 6.4071,
      car_battery_soc_2: 15,
      car_range_2: 48,
      car_max_range_2: 320,
      car_odometer_2: 98_765,
      car_connected_2: false,
      car_latitude_2: 50.9375,
      car_longitude_2: 6.9603,
      wallbox_power: 11_000,
      wallbox_car_connected: true,
    )
  end

  # Three cars, one for each color of the bar: the first charges at the
  # wallbox, the second is nearly empty, the third runs low
  def three_cars
    live_view(
      [car(1), car(2), car(3)],
      car_battery_soc_1: 45,
      car_range_1: 190,
      car_max_range_1: 420,
      car_odometer_1: 23_456,
      car_connected_1: true,
      car_latitude_1: 50.9226,
      car_longitude_1: 6.4071,
      car_battery_soc_2: 4,
      car_range_2: 13,
      car_max_range_2: 320,
      car_odometer_2: 98_765,
      car_connected_2: false,
      car_latitude_2: 50.9375,
      car_longitude_2: 6.9603,
      car_battery_soc_3: 18,
      car_range_3: 88,
      car_max_range_3: 490,
      car_odometer_3: 4_321,
      car_connected_3: false,
      car_latitude_3: 50.7753,
      car_longitude_3: 6.0839,
      wallbox_power: 11_000,
      wallbox_car_connected: true,
    )
  end

  # One car without a range sensor and without an estimate of its range
  def without_range_sensor
    live_view([car(1, range: false)], car_battery_soc_1: 62, car_odometer_1: 23_456)
  end

  # One car without a range sensor, with an estimate of its range (see
  # Car::RangeEstimate)
  def estimated_range
    live_view([car(1, range: false)], estimates: { 1 => 2.7 }, car_battery_soc_1: 62, car_odometer_1: 23_456)
  end

  private

  # The live view fills the height of its parent, as on the car page. Only
  # the admin sees the place of a car, so the preview shows none.
  def live_view(cars, estimates: {}, **data)
    component = Car::LiveView::Component.new(live: Live.new(cars, data, estimates:))

    render_with_template(template: 'car_live_view_component_preview/frame', locals: { component: })
  end

  # The name and the color of each car. The name comes from the database
  # otherwise, so the preview gives it to the car itself.
  CARS = {
    1 => ['Opel Stromboli', '#0ea5e9'],
    2 => ['Lotus Wattson', '#f97316'],
    3 => ['Škoda Voltavia', '#10b981'],
  }.freeze
  private_constant :CARS

  # A car without `range` has no range sensor, whatever the configuration,
  # and so no maximum range
  def car(id, range: true)
    name, color = CARS[id]

    Car.new(id:, color:, active_from: Date.new(2020, 1, 1)).tap do |car|
      car.define_singleton_method(:display_name) { name }
      car.define_singleton_method(:sensor?) { |role| %i[car_range car_max_range].exclude?(role) && super(role) } unless range
    end
  end
end
