# The select of the car on the car page: one car or "all". Each choice keeps
# the chart and the timeframe. With one car in the timeframe, "all" is that
# car, so the select shows that car and no "all".
class Car::Select::Component < ViewComponent::Base
  # `cars` are the cars of the timeframe, `car` is the selected one, or nil
  # for "all". A page other than the car page gives the address of a choice
  # as `path`, which takes the car id, or nil for "all". A page that shows
  # one car at a time leaves out "all".
  def initialize(cars:, car:, path: nil, all: true, button_class: Dropdown::Component::HEADER_BUTTON_CLASS)
    super()
    @cars = cars
    @car = car
    @path = path
    @all = all
    @button_class = button_class
  end

  attr_reader :cars, :car, :button_class

  # Each choice, "all" first
  def items
    @items ||= [
      (item(t('.all'), nil) if @all && !cars.one?),
      *cars.map { item(it.display_name, it) },
    ].compact
  end

  def selected
    shown&.id.to_s
  end

  private

  # The car the page shows, or nil for "all"
  def shown
    car || (cars.first if cars.one?)
  end

  # The button shows the short name, the menu the full name. A car shows in
  # its color.
  def item(name, choice)
    MenuItem::Component.new(
      name:,
      short_name: choice&.short_name,
      href: path(choice&.id),
      id: choice&.id.to_s,
      current: choice == shown,
      leading: (helpers.car_icon(choice.display_color) if choice),
      data: { turbo_action: 'replace' },
    )
  end

  def path(car_id)
    return @path.call(car_id) if @path

    helpers.url_for(
      controller: 'cars/home',
      action: 'index',
      sensor_name: helpers.sensor_name,
      timeframe: helpers.timeframe,
      car: car_id,
    )
  end
end
