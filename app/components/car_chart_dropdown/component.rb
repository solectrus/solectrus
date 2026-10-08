class CarChartDropdown::Component < ViewComponent::Base
  include ChartDropdownLogic

  # The order of the menu. A sensor the list does not know goes to the end,
  # so a new one shows up instead of disappearing.
  ORDER = %i[
    car_charging
    car_charging_costs
    car_driving_costs
    car_consumption_rate
    car_cost_rate
    car_distance
    car_battery_soc
    car_range
    car_max_range
  ].freeze
  private_constant :ORDER

  # The titles of the tiles that link to the charts
  TITLES = {
    car_charging: 'sensors.car_charged_short',
    car_distance: 'sensors.car_distance_short',
    car_battery_soc: 'sensors.car_battery_soc_short',
    car_range: 'sensors.car_range_short',
    car_max_range: 'sensors.car_max_range_short',
  }.freeze
  private_constant :TITLES

  def call
    render_chart_selector
  end

  private

  def page_key = :cars

  # The menu has the charts that the timeframe and the selected cars support
  # (see ChartDropdownLogic). A rate needs buckets of a day at least, the
  # range draws a day at most, and a chart of one car needs the selection of
  # one car. Only the admin gets the map of the places.
  def menu_items
    @menu_items ||= sensor_names.sort_by { ORDER.index(it) || ORDER.size }
  end

  def menu_config
    super.merge(grouped: false, display_names: menu_items.index_with { TITLES[it]&.then { I18n.t(it) } }.compact)
  end
end
