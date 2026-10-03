# A pair whose bars grow in opposite directions (grid export up and import
# down, see Sensor::Chart::Concerns::OppositeDirectionBars) is compared as a
# pair: its two bars of a year share one place, one above the zero line and
# one below, so a year still takes a single place per period. Every other
# sensor is compared on its own.
module Sensor::Chart::YearComparison::OppositePair
  extend ActiveSupport::Concern

  def options
    return super unless opposite_directions?

    # Magnitudes both ways, as in the regular chart.
    super.deep_merge(scales: { y: { ticks: { callback: 'formatAbs' } } })
  end

  private

  def chart_sensor_names
    opposite_directions? ? regular_chart.opposite_sensor_names : [sensor_name]
  end

  def opposite_directions?
    regular_chart.respond_to?(:opposite_sensor_names)
  end

  # The second sensor of the pair grows downward, as in the regular chart. It
  # is negated after the base class has clamped it to its range.
  def transform_data(data, name)
    validated = super
    return validated unless opposite_directions? && name == chart_sensor_names.last

    validated.map { -it if it }
  end

  def style_for_sensor(sensor)
    return super unless opposite_directions?

    super.merge(tooltipAbs: true)
  end

  # The tooltip names the year in its title already, so the rows of a single
  # sensor go without a label (see #dataset_for). Only a pair has to say which
  # of its two bars a row reads.
  def dataset_label(sensor, year)
    opposite_directions? ? sensor.display_name : year.to_s
  end
end
