# A costs chart that shows the parts its sum is made of, as segments of one
# bar. Every part comes out of the same query as the sum, so a segment cannot
# drift away from the number above the chart.
#
# A subclass names its segments, bottom first, and takes the split of the grid
# costs from #grid_cost_segments.
class Sensor::Chart::StackedCostsBase < Sensor::Chart::FinanceBase
  def y_scale_options
    stacked? ? super.merge(stacked: true) : super
  end

  private

  # The grid costs, split into the fee and the energy where the tariff carries
  # a base fee. Without one there is nothing to split off, and a second segment
  # would be empty at every point and still take a place in the legend.
  def grid_cost_segments
    @grid_cost_segments ||=
      BaseFee.any? ? %i[grid_base_fee grid_energy_costs] : [:grid_costs]
  end

  # A single segment is the sum itself, which is a plain bar rather than a
  # stack.
  def stacked?
    chart_sensor_names.length > 1
  end

  # Sensor::Chart::Base emits one dataset per chart sensor, in order. The chart
  # is titled after the sum, so the segments carry their short names.
  def datasets(chart_data_items)
    return super unless stacked?

    super.each_with_index.map do |dataset, index|
      sensor = Sensor::Registry[chart_data_items[index][:sensor_name]]

      dataset.merge(
        label: sensor.display_name(:short),
        stack: stack_id,
        noGradient: true,
      )
    end
  end

  # One stack per chart, so the name of the chart identifies it.
  def stack_id
    self.class.name.demodulize
  end
end
