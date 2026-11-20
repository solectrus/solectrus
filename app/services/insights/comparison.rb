# The figures of a sensor in a period beside those of an earlier one, for
# the insights below the trend overview (TrendOverview). The overview shows
# the change in percent, so the insights tell what is behind it: the two
# values, for a year the change of each month, and the days. What the
# tooltip of the segment shows, like the share of PV or the costs, stays
# out.
#
# The whole time has no earlier period (`base_timeframe: nil`). Below the
# overview of its years, the insights show the calendar of all months and
# the days, without a comparison.
class Insights::Comparison
  # One figure: its key (the label, or the first day of a month), the unit
  # of its values, its value in the earlier and in the current period, and
  # whether more is better
  Row =
    Data.define(:key, :unit, :base, :current, :more_is_better) do
      # The change from the earlier to the current period, nil without both
      def diff
        current - base if base && current
      end

      # :better or :worse, by the direction of the change, :same without a
      # change, and :neutral without better or worse (nil). None without
      # both values.
      def rating
        return unless diff
        return :same if diff.zero?
        return :neutral if more_is_better.nil?

        diff.positive? == more_is_better ? :better : :worse
      end
    end
  public_constant :Row

  # The comparison of a sensor. A chart of the car page reads the report of
  # the selected cars (Insights::CarComparison).
  def self.for(sensor:, timeframe:, base_timeframe:, car: nil)
    klass = sensor.is_a?(Sensor::Definitions::CarPageChart) ? Insights::CarComparison : self
    klass.new(sensor:, timeframe:, base_timeframe:, car:)
  end

  def initialize(sensor:, timeframe:, base_timeframe:, car: nil)
    @sensor = sensor
    @timeframe = timeframe
    @base_timeframe = base_timeframe
    @car = car
  end

  attr_reader :sensor, :timeframe, :base_timeframe

  def current_timeframe = @current_timeframe ||= Trend.compared_timeframe(timeframe)

  # The value of both periods, averaged like the trend of the overview. The
  # whole time has none: the page shows its value.
  def total
    return @total if defined?(@total)
    return @total = nil unless base_timeframe

    @total = row(:total, sensor.unit, ->(source) { value_of(source) })
  end

  # The change of each month against the same month of the year before,
  # for a year alone and where it compares (see #base). A month has no row
  # without a value of its own.
  def months
    return [] unless timeframe.year? && base

    @months ||= begin
      base_values = monthly(base)
      monthly(current).map do |month, value|
        Row.new(key: month, unit: sensor.unit, base: base_values[month.prev_year], current: value, more_is_better:)
      end
    end
  end

  # The figures of the days, then and now
  def days
    @days ||= day_figures.filter_map { row(*it) }
  end

  # [key, day, value] of the lowest and the highest day of the period. A
  # single day says nothing about a trend, so it has no comparison.
  def extremes
    %i[minimum maximum].filter_map do |key|
      day = current.public_send(key, :date)
      [key, day, current.public_send(key, :value)] if day
    end
  end

  # The longest streak of a charged battery, {from:, to:, length:}
  def streak = current.battery_soc_longest_streak

  # The calendar of the current period, with today, and the options of its
  # grid (Insights::HeatmapTile::Component)
  def heatmap_data
    return @heatmap_data if defined?(@heatmap_data)

    @heatmap_data = (current_timeframe.equal?(timeframe) ? current : source(timeframe)).heatmap_data
  end

  def heatmap_tile = {}

  private

  # Where the figures of a period come from
  def source(frame) = Insights.new(sensor:, timeframe: frame)

  # The days that compare, up to yesterday in a running period (see
  # Trend.compared_timeframe). The lowest day is then no day that has not
  # ended yet.
  def current = @current ||= source(current_timeframe)

  # The earlier period, where the overview compares with it: with data from
  # its first day on (Trend.complete?). Without it, the figures show the
  # current period alone, as the overview shows no change.
  def base
    return @base if defined?(@base)

    @base = (source(base_timeframe) if base_timeframe && Trend.complete?(base_timeframe, first_date:))
  end

  def first_date
    return @first_date if defined?(@first_date)

    @first_date = Trend.first_date(sensor, first_dates: SummaryValue.first_dates(Trend.summary_fields(sensor)))
  end

  def value_of(insights) = insights.raw_value(sensor.name)

  # A figure is better with more, as its sensor, unless it says otherwise.
  # A neutral sensor rates its figures neither way.
  def more_is_better = (sensor.more_is_better? unless sensor.neutral?)

  def row(key, unit, value, better = more_is_better)
    base_value = (value.call(base) if base)
    current_value = value.call(current)
    return if base_value.nil? && current_value.nil?

    Row.new(key:, unit:, base: base_value, current: current_value, more_is_better: better)
  end

  # [key, unit, value, more is better] of each figure of the days the
  # sensor can have
  def day_figures
    figures = [[:per_day, sensor.unit, lambda(&:per_day_value)]]
    return figures unless sensor.name == :battery_soc

    figures + [
      [:full_days, :days, lambda(&:battery_full_days), true],
      [:empty_days, :days, lambda(&:battery_empty_days), false],
      [:charged_consecutively, :days, ->(insights) { insights.battery_soc_longest_streak[:length] }, true],
    ]
  end

  # { first day of the month => value } of the months of a period with a
  # value, in one query
  def monthly(source)
    data =
      Sensor::Query::Total
        .new(source.timeframe) do |q|
          q.public_send(sensor.trend_aggregation, sensor.name)
          q.group_by :month
        end
        .call

    data.timestamps.zip(data.points).to_h { |time, point| [time.to_date.beginning_of_month, point.public_send(sensor.name)] }.compact
  end
end
