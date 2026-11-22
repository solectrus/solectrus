# The overview of a home page for the whole time (see TrendOverview): for
# each sensor of the page its value in each year, so the years compare at a
# glance. There is no earlier period to compare with, so a row has no
# change, but the best of the complete years. A row leads to the insights of
# its sensor over all years (Insights::Comparison::Component), and the years
# show as columns (TrendOverview::YearBars::Component).
#
# Two queries fetch what all rows need: the years of all sensors and the
# first day of each field.
class TrendOverview::Years < TrendOverview
  # One row: the sensor and its value in each year, like { 2025 => 1234.5 }.
  # A year that the sensor covers only partly (`partial_years`) does not
  # compete for the best year: the first year of the data or of the sensor,
  # and the running year.
  Row =
    Data.define(:sensor, :values, :partial_years) do
      # Nil with fewer than two complete years, which leave nothing to choose.
      # A year without anything, like a year without a charge, is no best
      # year either, and a neutral sensor has none.
      def best_year
        return if sensor.neutral?

        complete = values.except(*partial_years).compact.reject { |_, value| value.zero? }
        return if complete.size < 2

        sensor.more_is_better? ? complete.max_by(&:last).first : complete.min_by(&:last).first
      end

      def partial?(year) = partial_years.include?(year)

      # A sum or a percentage starts at zero. A temperature or the efficiency
      # of the heat pump has no true zero.
      def zero_based? = !sensor.unit.in?(DIFFERENCE_UNITS)
    end
  public_constant :Row

  # A sensor without a value in any year has no row, like the maximum range
  # of several cars, which only one car has
  def rows
    @rows ||=
      sensor_names.filter_map do |name|
        sensor = Sensor::Registry[name]
        values = values_of(sensor)
        Row.new(sensor:, values:, partial_years: partial_years_of(sensor)) if values.values.any?
      end
  end

  private

  # A year without a value of the sensor, like one before it was installed,
  # stays nil
  def values_of(sensor)
    years.zip(series.points.map { it.public_send(sensor.name) }).to_h
  end

  # A sensor added later starts within a year, which is partial too
  def partial_years_of(sensor)
    first_date = first_date_of(sensor)
    return partial_years unless first_date && first_date > first_date.beginning_of_year

    partial_years | [first_date.year]
  end

  # The first day of the sensor, nil without a value
  def first_date_of(sensor) = Trend.first_date(sensor, first_dates:)

  def years
    @years ||= series.timestamps.map(&:year)
  end

  # The years that the data covers only partly
  def partial_years
    @partial_years ||= years.select { timeframe.partial_period?(Date.new(it), :year) }
  end

  def series
    @series ||=
      Sensor::Query::Total
        .new(timeframe) do |q|
          sensor_names.each { q.trend(it) }
          q.group_by :year
        end
        .call
  end
end
