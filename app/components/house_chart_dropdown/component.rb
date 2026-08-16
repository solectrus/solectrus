class HouseChartDropdown::Component < ViewComponent::Base
  include ChartDropdownLogic

  # The house itself. It opens and closes the menu.
  HOUSE_TOP = :house_power
  HOUSE_BOTTOM = :house_power_without_custom
  private_constant :HOUSE_TOP, :HOUSE_BOTTOM

  def call
    render_chart_selector
  end

  private

  def page_key = :house

  def menu_items
    @menu_items ||=
      join_groups(
        [HOUSE_TOP] & sensor_names,
        consumers,
        [HOUSE_BOTTOM] & sensor_names,
      )
  end

  # Everything the page shows besides the house itself, so a sensor the page
  # gains lands in a group instead of falling out of the menu.
  def consumers
    (sensor_names - [HOUSE_TOP, HOUSE_BOTTOM]).sort_by do |sensor_name|
      Sensor::Registry[sensor_name].display_name.downcase
    end
  end
end
