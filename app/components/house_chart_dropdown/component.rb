class HouseChartDropdown::Component < ChartDropdownBase::Component
  private

  def menu_items
    @menu_items ||=
      [
        :house_power,
        :_,
        *Sensor::Config
          .house_power_included_custom_sensors
          .sort_by { |sensor| sensor.display_name.downcase }
          .map(&:name),
        :_,
        :house_power_without_custom,
      ]
  end
end
