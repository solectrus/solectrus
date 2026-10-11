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

  # Each choice: "all" first, then the cars, then the guest. A line divides
  # the cars from the choices around them.
  def items
    @items ||= [
      (item(t('.all'), nil, leading: other_icon('layer-group')) if @all),
      *cars.each_with_index.map { |car, index| item(car.display_name, car.id, car, separator_before: @all && index.zero?) },
      (item(t('.guest'), CarSelection::GUEST, leading: other_icon('user'), separator_before: true) if @guest),
    ].compact
  end

  def selected
    @guest_selected ? CarSelection::GUEST : car&.id.to_s
  end

  private

  # The button shows the short name, the menu the full name. A car shows in
  # its color.
  def item(name, param, choice = nil, leading: nil, separator_before: false)
    MenuItem::Component.new(
      name:,
      short_name: choice&.short_name,
      href: path(param),
      id: param.to_s,
      current: param.to_s == selected,
      leading: choice ? helpers.car_icon(choice.display_color) : leading,
      separator_before:,
      data: { turbo_action: 'replace' },
    )
  end

  # The icon of a choice without a car, in the width of the car icon, so the
  # names stand in one column. It takes the color of the text, on the button
  # and in the menu.
  def other_icon(name)
    helpers.icon(name, class: 'shrink-0 w-[1.25em] opacity-60')
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
