# The options of the top 10 in one dropdown beside the sensor select: the
# car, the calculation and the order, each a group of its own. The button
# shows an icon alone, so on a phone the line holds both buttons, and the
# menu marks the current choice of each group (see Ui::Dropdown::Component).
# The header of the desktop has the same two buttons.
class Top10::Options::Component < ViewComponent::Base
  ORDER_ICONS = { 'desc' => 'arrow-down-wide-short', 'asc' => 'arrow-down-short-wide' }.freeze
  private_constant :ORDER_ICONS

  # `calc` is nil for a sensor without a choice of the calculation.
  # `phone: true` for the phone, above the list on the gray page.
  def initialize(sensor:, calc:, permitted_params:, phone: false)
    super()
    @phone = phone
    @sensor = sensor
    @calc = calc
    @permitted_params = permitted_params
    @car_choice = Top10::CarChoice.new(sensor)
  end

  def groups
    [car_group, calc_group, order_group].compact
  end

  def dropdown_options
    @phone ? Ui::Dropdown::Component.pill_options : {}
  end

  def display
    helpers.icon('sliders', class: 'fa-fw')
  end

  private

  def car_group
    return unless @car_choice.offered?

    {
      name: t('.car'),
      items: Car::Select::Component.menu_items(
        helpers,
        cars: @car_choice.cars,
        selected: @car_choice.car&.id.to_s,
        path: ->(id) { path(sensor_name: @car_choice.sensor_name(id)) },
        all: @car_choice.all?,
      ),
    }
  end

  def calc_group
    return unless @calc

    items =
      @sensor.allowed_aggregations.map do |agg|
        Ui::MenuItem::Component.new(
          name: t(".calcs.#{agg}", default: agg.to_s.capitalize),
          id: agg,
          href: path(calc: agg.to_s),
          current: @calc == agg.to_s,
        )
      end

    { name: t('.calc'), items: }
  end

  # The icon leads the name in the width of the icon of a car, so the names
  # stand in one column beside the cars
  def order_group
    items =
      ORDER_ICONS.map do |order, icon|
        Ui::MenuItem::Component.new(
          name: t(".orders.#{order}"),
          id: order,
          leading: helpers.icon(icon, class: 'shrink-0 w-[1.25em] opacity-60'),
          href: path(sort: order),
          current: @permitted_params[:sort].to_s == order,
        )
      end

    { name: t('.order'), items: }
  end

  def path(**)
    helpers.url_for(**@permitted_params, **, only_path: true)
  end
end
