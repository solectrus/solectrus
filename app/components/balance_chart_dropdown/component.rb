class BalanceChartDropdown::Component < ViewComponent::Base
  include ChartDropdownLogic

  def call
    render_chart_selector
  end

  private

  def page_key = :balance

  # The balance has no grouping, so the menu goes by name.
  def menu_items
    @menu_items ||= sensor_names.sort_by { |sensor_name| Sensor::Registry[sensor_name].display_name(:long).downcase }
  end
end
