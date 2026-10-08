# @label Car live view
# @logical_path data_visualization
# @display max_width 64rem
class CarLiveViewComponentPreview < ViewComponent::Preview
  # Car::Live with fixed values instead of the latest values of InfluxDB
  class Live < Car::Live
    def initialize(cars, data)
      super(cars, home: nil)
      @data = Sensor::Data::Single.new(data, timeframe: Timeframe.now, times: data.transform_values { Time.current })
    end

    attr_reader :data
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
      car_battery_soc_2: 15,
      car_range_2: 48,
      car_max_range_2: 320,
      car_odometer_2: 98_765,
      car_connected_2: false,
      wallbox_power: 11_000,
      wallbox_car_connected: true,
    )
  end

  # Three cars, one for each color of the badge: the first charges at the
  # wallbox, the second is nearly empty, the third runs low
  def three_cars
    live_view(
      [car(1), car(2), car(3)],
      car_battery_soc_1: 45,
      car_range_1: 190,
      car_max_range_1: 420,
      car_odometer_1: 23_456,
      car_connected_1: true,
      car_battery_soc_2: 4,
      car_range_2: 13,
      car_max_range_2: 320,
      car_odometer_2: 98_765,
      car_connected_2: false,
      car_battery_soc_3: 18,
      car_range_3: 88,
      car_max_range_3: 490,
      car_odometer_3: 4_321,
      car_connected_3: false,
      wallbox_power: 11_000,
      wallbox_car_connected: true,
    )
  end

  private

  # The live view fills the height of its parent, as on the car page
  def live_view(cars, data)
    render_with_template(
      template: 'car_live_view_component_preview/frame',
      locals: {
        live: Live.new(cars, data),
        named: cars.many?,
      },
    )
  end

  def car(id) = Car.new(id:, active_from: Date.new(2020, 1, 1))
end
