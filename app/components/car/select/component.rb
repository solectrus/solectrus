# The select of the car on the car page: one car, "all" or the guests. Each
# choice keeps the chart and the timeframe. "all" stays also with one car in
# the timeframe, because "all" adds the guest sessions to that car.
class Car::Select::Component < ViewComponent::Base
  # `cars` are the cars of the timeframe, `car` is the selected one, or nil
  # for "all". A page other than the car page gives the address of a choice
  # as `path`, which takes the car id, or nil for "all". A page that shows
  # one car at a time leaves out "all". The car page also offers the guest
  # sessions (`guest: true`), and `guest_selected` is whether it shows them.
  def initialize(cars:, car:, path: nil, all: true, guest: false, guest_selected: false, button_class: Ui::Dropdown::Component::HEADER_BUTTON_CLASS) # rubocop:disable Metrics/ParameterLists
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
    @items ||= self.class.menu_items(helpers, cars:, selected:, path: method(:path), all: @all, guest: @guest)
  end

  def selected
    @guest_selected ? CarSelection::GUEST : car&.id.to_s
  end

  # The choices as items of a menu. The options of the top 10 take them too
  # (see Top10::Options::Component), so they take the helpers of the view and
  # the address of a choice as `path`.
  #
  # The button shows the short name, the menu the full name. A car shows in
  # its color. A choice without a car has an icon in the width of the car
  # icon, so the names stand in one column.
  def self.menu_items(helpers, cars:, selected:, path:, all: true, guest: false)
    item = lambda do |name, param, leading:, short_name: nil, separator_before: false|
      Ui::MenuItem::Component.new(
        name:,
        short_name:,
        leading:,
        separator_before:,
        href: path.call(param),
        id: param.to_s,
        current: param.to_s == selected,
        data: { turbo_action: 'replace' },
      )
    end
    other_icon = ->(name) { helpers.icon(name, class: 'shrink-0 w-[1.25em] opacity-60') }

    [
      (item.call(translate('.all'), nil, leading: other_icon.call('layer-group')) if all),
      *cars.each_with_index.map do |car, index|
        item.call(
          car.display_name,
          car.id,
          leading: helpers.car_icon(car.display_color),
          short_name: car.short_name,
          separator_before: all && index.zero?,
        )
      end,
      (item.call(translate('.guest'), CarSelection::GUEST, leading: other_icon.call('user'), separator_before: true) if guest),
    ].compact
  end

  private

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
