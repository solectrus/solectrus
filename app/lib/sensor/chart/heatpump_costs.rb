class Sensor::Chart::HeatpumpCosts < Sensor::Chart::FinanceBase
  STACK_ID = 'HeatpumpCosts'.freeze
  private_constant :STACK_ID

  # Both segments are charted in the color of the power sensor they were
  # calculated from, so they match the heat pump power chart.
  COLOR_SOURCES = {
    heatpump_costs_grid: :heatpump_power_grid,
    heatpump_costs_pv: :heatpump_power_pv,
  }.freeze
  private_constant :COLOR_SOURCES

  # Within this chart the segments are just the grid and the PV share, so they
  # are labelled by their origin rather than by their own sensor names.
  LABEL_KEYS = {
    heatpump_costs_grid: 'sensors.grid_costs',
    heatpump_costs_pv: 'sensors.opportunity_costs',
  }.freeze
  private_constant :LABEL_KEYS

  # Stacked: the grid and the PV share of the heat pump costs add up to the
  # total costs, so they are charted as two segments of one bar.
  def chart_sensor_names
    %i[heatpump_costs_grid heatpump_costs_pv]
  end

  def y_scale_options
    super.merge(stacked: true)
  end

  def color_class(sensor)
    Sensor::Registry[COLOR_SOURCES[sensor.name]].color_background
  end

  private

  # Sensor::Chart::Base emits one dataset per chart sensor, in order.
  def datasets(chart_data_items)
    super.each_with_index.map do |dataset, index|
      sensor_name = chart_data_items[index][:sensor_name]

      dataset.merge(
        label: I18n.t(LABEL_KEYS[sensor_name]),
        stack: STACK_ID,
        noGradient: true,
      )
    end
  end
end
