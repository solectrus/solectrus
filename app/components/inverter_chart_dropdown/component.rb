class InverterChartDropdown::Component < ViewComponent::Base
  include ChartDropdownLogic

  def call
    render_chart_selector
  end

  private

  def menu_items
    @menu_items ||= begin
      sensors = Sensor::Config.inverter_sensors.map(&:name)
      if sensors.first == :inverter_power && sensors.length > 1
        [sensors.first, :_, *sensors.drop(1)]
      else
        sensors
      end
    end
  end
end
