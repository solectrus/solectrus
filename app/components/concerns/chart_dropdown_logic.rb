module ChartDropdownLogic
  extend ActiveSupport::Concern

  SEPARATOR = :_
  private_constant :SEPARATOR

  included do
    attr_reader :sensor_name, :timeframe
  end

  def initialize(sensor_name:, timeframe:)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
  end

  # ViewComponent ignores `call` defined in included modules, so each
  # including class defines its own `call` that delegates here.
  def render_chart_selector
    render(
      ChartSelector::Component.new(
        sensor_name:,
        timeframe:,
        sensor_names:,
        menu_config:,
      ),
    )
  end

  private

  # Which sensors a page shows is a decision of the sensors, not of the menu.
  def sensor_names
    @sensor_names ||= Sensor::HomePage.sensor_names(page_key)
  end

  def menu_config
    { items: menu_items }
  end

  # The order of the menu. Subclasses arrange the sensors of their page, but
  # they can only arrange what they get.
  def menu_items = sensor_names

  # One separator between two groups, and none around an empty one, so the
  # menu cannot draw a line around nothing. Every group gets a leading
  # separator and the first one loses it again, so no group at all gives an
  # empty menu instead of nil.
  def join_groups(*groups)
    groups.compact_blank.flat_map { [SEPARATOR, *it] }.drop(1)
  end
end
