class InverterChartDropdown::Component < ChartDropdownBase::Component
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
