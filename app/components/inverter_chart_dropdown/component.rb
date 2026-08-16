class InverterChartDropdown::Component < ViewComponent::Base
  include ChartDropdownLogic

  def call
    render_chart_selector
  end

  private

  def page_key = :inverter

  # A separator sets the total apart from the single inverters.
  def menu_items
    @menu_items ||=
      join_groups(
        [:inverter_power] & sensor_names,
        sensor_names - [:inverter_power],
      )
  end
end
