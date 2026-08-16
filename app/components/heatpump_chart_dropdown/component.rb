class HeatpumpChartDropdown::Component < ViewComponent::Base
  include ChartDropdownLogic

  # The order of the time series. A sensor the list does not know goes to the
  # end, so a new one shows up instead of disappearing.
  ORDER = %i[
    heatpump_power
    heatpump_costs
    heatpump_cop
    outdoor_temp
    heatpump_heating_power
    heatpump_tank_temp
  ].freeze
  private_constant :ORDER

  SCATTER = :heatpump_cop_scatter
  private_constant :SCATTER

  def call
    render_chart_selector
  end

  private

  def page_key = :heatpump

  # The scatter chart is not a time series, so it stands apart.
  def menu_items
    @menu_items ||= join_groups(time_series, [SCATTER] & sensor_names)
  end

  def time_series
    series = sensor_names - [SCATTER]

    ORDER.select { series.include?(it) } + (series - ORDER)
  end

  def menu_config
    super.merge(
      grouped: false,
      display_names: {
        heatpump_power: I18n.t('sensors.heatpump_power_short'),
      },
    )
  end
end
