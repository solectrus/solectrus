class HeatpumpChartDropdown::Component < ChartDropdownBase::Component
  private

  def menu_items
    %i[
      outdoor_temp
      heatpump_heating_power
      heatpump_cop
      heatpump_tank_temp
      heatpump_costs
      _
      heatpump_cop_scatter
    ]
  end
end
