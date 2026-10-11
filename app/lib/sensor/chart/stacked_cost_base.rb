# Shared base for stacked "grid vs. PV" cost charts (heat pump, wallbox, ...).
#
# Subclasses name the two sensors the chart is built from:
#   - finance_sensor_name: e.g. :heatpump_costs
#   - power_sensor_name:   e.g. :heatpump_power
#
# The four sensors that are actually charted follow by convention:
#   cost_grid_sensor  = "#{finance_sensor_name}_grid"
#   cost_pv_sensor    = "#{finance_sensor_name}_pv"
#   power_grid_sensor = "#{power_sensor_name}_grid"
#   power_pv_sensor   = "#{power_sensor_name}_pv"
#
# The money values themselves come from the sensor definitions, so this chart
# only has to name them -- see Sensor::Chart::FinanceBase.
class Sensor::Chart::StackedCostBase < Sensor::Chart::FinanceBase
  # Stacked: the grid and the PV share of the costs add up to the total, so
  # they are charted as two segments of one bar.
  def chart_sensor_names
    [cost_grid_sensor, cost_pv_sensor]
  end

  def y_scale_options
    super.merge(stacked: true)
  end

  # Both segments are charted in the color of the power sensor they were
  # calculated from, so they match the corresponding power chart.
  def color_class(sensor)
    Sensor::Registry[color_sources[sensor.name]].color_background
  end

  private

  def finance_sensor_name
    # simplecov:disable
    raise NotImplementedError, 'Subclasses must implement finance_sensor_name'
    # simplecov:enable
  end

  def power_sensor_name
    # simplecov:disable
    raise NotImplementedError, 'Subclasses must implement power_sensor_name'
    # simplecov:enable
  end

  def cost_grid_sensor
    :"#{finance_sensor_name}_grid"
  end

  def cost_pv_sensor
    :"#{finance_sensor_name}_pv"
  end

  def power_grid_sensor
    :"#{power_sensor_name}_grid"
  end

  def power_pv_sensor
    :"#{power_sensor_name}_pv"
  end

  def color_sources
    { cost_grid_sensor => power_grid_sensor, cost_pv_sensor => power_pv_sensor }
  end

  # Within this chart the segments are just the grid and the PV share, so they
  # are labelled by their origin rather than by their own sensor names.
  def label_keys
    {
      cost_grid_sensor => 'sensors.grid_costs',
      cost_pv_sensor => 'sensors.opportunity_costs',
    }
  end

  def stack_id
    @stack_id ||= self.class.name.demodulize.freeze
  end

  # Sensor::Chart::Base emits one dataset per chart sensor, in order. Only
  # the items of the chart sensors become a segment, and the tooltip adds up
  # the grid and the PV share.
  def datasets(chart_data_items)
    cost_items =
      chart_data_items.select do |item|
        chart_sensor_names.include?(item[:sensor_name])
      end

    super(cost_items).each_with_index.map do |dataset, index|
      dataset.merge(
        label: I18n.t(label_keys[cost_items[index][:sensor_name]]),
        stack: stack_id,
        summed: true,
        noGradient: true,
      )
    end
  end
end
