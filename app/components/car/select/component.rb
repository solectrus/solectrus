# The select of the car on the car page: one car or "all". With one car,
# there is no select. Each choice keeps the chart and the timeframe.
class Car::Select::Component < ViewComponent::Base
  # `cars` are all cars of the installation, `car` is the selected one, or nil
  # for "all".
  def initialize(cars:, car:)
    super()
    @cars = cars
    @car = car
  end

  attr_reader :cars, :car

  def render?
    cars.many?
  end

  # Each choice, "all" first
  def items
    [
      PillNav::Component::Item.new(label: t('.all'), href: path(nil), current: car.nil?, color: nil),
      *cars.map do
        PillNav::Component::Item.new(
          label: it.display_name,
          href: path(it),
          current: it == car,
          color: it.display_color,
        )
      end,
    ]
  end

  private

  def path(choice)
    helpers.url_for(
      controller: 'cars/home',
      action: 'index',
      sensor_name: helpers.sensor_name,
      timeframe: helpers.timeframe,
      car: choice&.id,
    )
  end
end
