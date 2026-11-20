# The overview of a month or a year (see TrendOverview): for each sensor of
# the page its change against an earlier period, the year before or the
# month before (TrendOverview::Change::Component).
#
# Three queries fetch what all rows need: the totals of each period and the
# first day of each field.
class TrendOverview::Changes < TrendOverview
  # One row: the sensor and its trend
  Row =
    Data.define(:sensor, :trend) do
      # The change of a percentage in points, of a temperature or of the
      # efficiency of the heat pump as the difference in its unit, and of
      # any other value, like a sum or a rate per 100 km, in percent
      def kind
        if sensor.unit == :percent
          :points
        elsif sensor.unit.in?(DIFFERENCE_UNITS)
          :difference
        else
          :percent
        end
      end

      # Nil without a value of the period or of the earlier period. A
      # percentage needs a base value other than zero (Trend#percent), a
      # difference does not.
      def change
        kind == :percent ? trend.percent : trend.diff
      end

      # Decimal places of the change: a percentage or its points have none
      def precision
        kind == :difference ? 1 : 0
      end

      # :better, :worse or :same, as the change rounds, and :neutral for a
      # sensor without better or worse. None without a change.
      def rating
        return unless change
        return :same if change.round(precision).zero?
        return :neutral if sensor.neutral?

        change.positive? == sensor.more_is_better? ? :better : :worse
      end
    end
  public_constant :Row

  def initialize(page:, timeframe:, base:)
    super(page:, timeframe:)
    @base = base
  end

  attr_reader :base

  # The insights of a row compare with the same earlier period
  def link_params = { base: TrendOverview.base_param(base) }

  # A sensor without a value in either period has no row, like the maximum
  # range of several cars, which only one car has
  def rows
    @rows ||=
      sensor_names.filter_map do |name|
        sensor = Sensor::Registry[name]
        trend = trend_for(sensor)
        Row.new(sensor:, trend:) if trend.current_value || trend.base_value
      end
  end

  def base_timeframe
    @base_timeframe ||= Trend.base_timeframe(timeframe, base)
  end

  private

  def trend_for(sensor)
    Trend.new(
      sensor:,
      timeframe:,
      current_value: current_data.public_send(sensor.name)&.to_f,
      base:,
      base_data:,
      first_date: Trend.first_date(sensor, first_dates:),
    )
  end

  # The days that compare, up to yesterday in a running period (see
  # Trend.compared_timeframe)
  def current_data
    @current_data ||= totals(Trend.compared_timeframe(timeframe))
  end

  def base_data
    @base_data ||= totals(base_timeframe)
  end

  def totals(frame)
    Sensor::Query::Total
      .new(frame) do |q|
        sensor_names.each { q.public_send(Sensor::Registry[it].trend_aggregation, it) }
      end
      .call
  end
end
