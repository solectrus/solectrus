class ChartDropdown::Car::Component < ViewComponent::Base
  include ChartDropdown::Logic

  # The titles of the menu that differ from the names of the sensors
  TITLES = {
    car_battery_soc: 'sensors.car_battery_soc_short',
  }.freeze
  private_constant :TITLES

  # With `all`, the menu has the charts of each column of the overview with a
  # chart, for a phone with one chart below both columns. The overview loads
  # each pick in the column of its chart (see car_overview_controller.ts).
  def initialize(all: false, **)
    super(**)
    @all = all
  end

  def call
    render_chart_selector
  end

  private

  def page_key = :cars

  # The menu has the charts of the column of the chart, or of each column,
  # that the period has (see Cars::Selectable#section_charts) and that the
  # timeframe and the selected cars support (see ChartDropdown::Logic), a
  # group per column. A rate needs buckets of a day at least, and a chart of
  # one car needs the selection of one car.
  def sensor_names = column_charts.flatten & super

  def menu_items = join_groups(*column_charts.map { it & sensor_names })

  def column_charts
    sections = @all ? helpers.chart_sections : [Car::Section.of(sensor_name)]
    sections.map { helpers.section_charts.fetch(it, []) }
  end

  def menu_config
    super.merge(
      grouped: false,
      display_names: menu_items.index_with { TITLES[it]&.then { I18n.t(it) } }.compact,
      chart_controller: 'car-overview',
    )
  end
end
