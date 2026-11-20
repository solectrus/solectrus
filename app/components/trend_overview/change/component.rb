# The change of a row of the overview of a month or a year
# (TrendOverview::Changes): a bar on the track and the change as a figure,
# two columns of the row (TrendOverview::Component).
#
# The bars of all groups share one scale around zero, up to CAP to each
# side, so they compare at a glance (TrendOverview::Bar::Component). The
# figure tells the size of a change beyond the scale. An average with a
# unit of its own, like a temperature, has no place on that scale and shows
# the figure alone.
class TrendOverview::Change::Component < ViewComponent::Base
  CAP = 50
  private_constant :CAP

  # The color of a change that is better, worse or the same, also below the
  # overview (Insights::Comparison::Component). A neutral change has none.
  RATING_CLASSES = {
    better: 'text-signal-positive',
    worse: 'text-signal-negative',
    same: 'text-muted',
  }.freeze
  public_constant :RATING_CLASSES

  def initialize(row:)
    super()
    @row = row
  end

  attr_reader :row

  delegate :change, :rating, :kind, to: :row

  # The bar of a change on the scale. An average with a unit of its own and
  # a row without a value to compare with leave the track empty.
  def bar
    scaled = change unless kind == :difference
    TrendOverview::Bar::Component.new(change: scaled, rating: (rating if scaled), scale: CAP)
  end

  def value_class
    RATING_CLASSES[rating] if change
  end

  def value
    return '–' unless change
    return "±#{format_value(0, unit: row.sensor.unit)}" if rating == :same && kind == :difference
    return "±0#{suffix}" if rating == :same

    case kind
    when :percent
      format_value(change, unit: :percent)
    when :points
      "#{format_value(change, unit: :unitless)}#{suffix}"
    else
      format_value(change, unit: row.sensor.unit, precision: row.precision)
    end
  end

  private

  # The unit of a percent or its points. A difference has the unit of its
  # sensor. The figure stays on one line (see trend_overview/component.css),
  # so a plain space does.
  def suffix
    kind == :percent ? ' %' : " #{t('trend.percentage_points')}"
  end

  def format_value(value, unit:, precision: 0)
    Sensor::ValueFormatter.new(value, unit:, precision:, sign: true).to_s
  end
end
