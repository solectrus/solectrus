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
  # calculated from, so they match the corresponding power chart. The year
  # comparison draws the finance sensor itself and asks this chart for its
  # color, so anything else keeps the color of its own sensor.
  def color_class(sensor)
    source = color_sources[sensor.name]
    return super unless source

    Sensor::Registry[source].color_background
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

  # Sensor::Chart::Base emits one dataset per chart sensor, in order. Items
  # that are not chart sensors are left to subclasses (see CarChargingCosts, which
  # appends a segment that has no sensor of its own).
  def datasets(chart_data_items)
    cost_items =
      chart_data_items.select do |item|
        chart_sensor_names.include?(item[:sensor_name])
      end

    super(cost_items).each_with_index.map do |dataset, index|
      dataset.merge(
        label: I18n.t(label_keys[cost_items[index][:sensor_name]]),
        stack: stack_id,
        noGradient: true,
      )
    end
  end

  def find_chart_data(chart_data_items, sensor_name)
    chart_data_items.find { |item| item[:sensor_name] == sensor_name } ||
      empty_dataset(sensor_name)
  end

  # A segment that has no sensor of its own, so it cannot go through
  # Sensor::Chart::Base#build_dataset. Styled like its siblings, which get
  # their look from #style_for_sensor.
  def build_cost_dataset(id, label, data, color_class)
    {
      id: id.to_s,
      label:,
      data:,
      stack: stack_id,
      noGradient: true,
      fill: true,
      borderWidth: 1,
      pointRadius: 0,
      pointHoverRadius: 5,
      borderRadius: (3 if type == 'bar'),
      colorClass: color_class,
    }.compact
  end
end
