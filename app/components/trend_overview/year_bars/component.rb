# The years of a row of the overview of the whole time (TrendOverview::Years)
# as small columns, one per year, so the years of all rows line up. The best
# year stands out in green, and a year that the data covers only partly, the
# first and the running one, is pale. A mouse over a column shows its year
# and its value, and whether it is the best or a partial year.
#
# Each row has a scale of its own. A sum or a percentage starts at zero. A
# temperature or the efficiency of the heat pump has no true zero, so its
# columns start below its lowest year, and the lowest year keeps a stub.
class TrendOverview::YearBars::Component < ViewComponent::Base
  # The height of the lowest year of a value without a true zero, in percent
  STUB = 20
  private_constant :STUB

  def initialize(row:)
    super()
    @row = row
  end

  attr_reader :row

  delegate :values, to: :row

  def bar_class(year)
    [
      'trend-overview-year',
      year == best_year ? 'bg-signal-positive' : 'bg-slate-400/70',
      ('is-partial' if row.partial?(year)),
    ]
  end

  def bar_style(value) = "height: #{height(value).round(1)}%"

  def formatted(value)
    Sensor::ValueFormatter.new(value, unit: row.sensor.unit, context: :total, scaling: :kilo).to_s
  end

  # The best year, or a year that the data covers only partly
  def note(year)
    if year == best_year
      t('.best')
    elsif row.partial?(year)
      t('.partial')
    end
  end

  def best_year
    return @best_year if defined?(@best_year)

    @best_year = row.best_year
  end

  private

  def height(value)
    if !row.zero_based?
      relative_height(value)
    elsif max.positive?
      value.clamp(0, max) * 100.0 / max
    else
      0
    end
  end

  def relative_height(value)
    return 100 if max == min

    ((value - min) * (100.0 - STUB) / (max - min)) + STUB
  end

  def present_values = @present_values ||= values.values.compact

  def max = @max ||= present_values.max

  def min = @min ||= present_values.min
end
