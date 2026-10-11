# The select of the car on the car page: one car, "all" or the guests. Each
# choice keeps the chart and the timeframe. "all" stays also with one car in
# the timeframe, because "all" adds the guest sessions to that car.
class Car::Select::Component < ViewComponent::Base
  # `cars` are the cars of the timeframe, `car` is the selected one, or nil
  # for "all". A page other than the car page gives the address of a choice
  # as `path`, which takes the car id, or nil for "all". A page that shows
  # one car at a time leaves out "all". The car page also offers the guest
  # sessions (`guest: true`), and `guest_selected` is whether it shows them.
  def initialize(cars:, car:, path: nil, all: true, guest: false, guest_selected: false, button_class: Dropdown::Component::HEADER_BUTTON_CLASS) # rubocop:disable Metrics/ParameterLists
    super()
    @cars = cars
    @car = car
    @path = path
    @all = all
    @guest = guest
    @guest_selected = guest_selected
    @button_class = button_class
  end

  attr_reader :cars, :car, :button_class

  # The button of the select in the stats of a phone
  STATS_BUTTON_CLASS = 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300'.freeze
  public_constant :STATS_BUTTON_CLASS

  # Each choice, "all" first and the guest last
  def items
    @items ||= [
      (item(t('.all'), nil) if @all),
      *cars.map { item(it.display_name, it.id, it) },
      (item(t('.guest'), CarSelection::GUEST) if @guest),
    ].compact
  end

  def selected
    @guest_selected ? CarSelection::GUEST : car&.id.to_s
  end

  private

  # The button shows the short name, the menu the full name. A car shows in
  # its color.
  def item(name, param, choice = nil)
    MenuItem::Component.new(
      name:,
      short_name: choice&.short_name,
      href: path(param),
      id: param.to_s,
      current: param.to_s == selected,
      leading: (helpers.car_icon(choice.display_color) if choice),
      data: { turbo_action: 'replace' },
    )
  end

  def path(param)
    return @path.call(param) if @path

    helpers.url_for(
      controller: 'cars/home',
      action: 'index',
      sensor_name: helpers.sensor_name,
      timeframe: helpers.timeframe,
      car: param,
    )
  end
end
