class HeatpumpChartDropdown::Component < ChartDropdownBase::Component
  private

  def menu_config
    {
      items: filtered_menu_items,
      grouped: false,
      display_names: {
        heatpump_power: I18n.t('sensors.heatpump_power_short'),
      },
    }
  end

  def menu_items
    %i[
      heatpump_power
      heatpump_costs
      heatpump_cop
      outdoor_temp
      heatpump_heating_power
      heatpump_tank_temp
      _
      heatpump_cop_scatter
    ]
  end
end
