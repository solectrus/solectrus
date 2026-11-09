class ChartDropdown::Car::Component < ViewComponent::Base
  include ChartDropdown::Logic

  # The titles of the menu that differ from the names of the sensors. The
  # costs of both columns share the name of their sensor, so the menu names
  # the column as well.
  TITLES = {
    car_battery_soc: 'sensors.car_battery_soc_short',
    car_driving_costs: '.car_driving_costs',
    car_charging_costs: '.car_charging_costs',
  }.freeze
  private_constant :TITLES

  def call
    render_chart_selector
  end

  private

  def page_key = :cars

  # The page shows one chart, so the menu has the charts of each column with
  # a chart (see Cars::Selectable#section_charts) that the timeframe and the
  # selected cars support (see ChartDropdown::Logic), a group per column. A
  # rate needs buckets of a day at least, and a chart of one car needs the
  # selection of one car.
  def sensor_names = column_charts.flatten & super

  def menu_items = join_groups(*column_charts.map { it & sensor_names })

  def column_charts = helpers.chart_sections.map { helpers.section_charts.fetch(it, []) }

  def menu_config
    super.merge(
      grouped: false,
      display_names: menu_items.index_with { TITLES[it]&.then { t(it) } }.compact,
    )
  end
end
