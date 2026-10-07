# The car days of a date range, read at once: for each car and day the
# distance and the maximum range from the daily summaries, and the sums of
# its charging sessions. The wallbox sessions without a car, the guest
# sessions and the sessions that are not assigned, are days without a car.
#
# Each number of the car page and of its charts is a sum over these days (see
# Car::Report), so a column of a chart and the tile of the same period agree.
# Two queries read all days, one for the summaries and one for the sessions.
class Car::Ledger
  # The sessions of a car, or of no car, of one guest mark and kind on a day
  Row = Data.define(:date, :car_id, :guest, :kind, :sums)
  private_constant :Row

  def initialize(cars, dates)
    @cars = cars
    @dates = dates
  end

  attr_reader :cars, :dates

  # The Sums of the sessions of the cars on the given dates, of one kind or
  # of each kind
  def sessions(dates, kind: nil)
    ids = cars.map(&:id)
    kind = kind&.to_s
    sum_rows(dates) { ids.include?(it.car_id) && (kind.nil? || it.kind == kind) }
  end

  # The Sums of the guest sessions on the given dates
  def guest_sessions(dates)
    sum_rows(dates) { it.car_id.nil? && it.guest }
  end

  # The Sums of the wallbox sessions on the given dates that are not assigned
  def unassigned_sessions(dates)
    sum_rows(dates) { it.car_id.nil? && !it.guest }
  end

  # The distance (km) of the cars on the given dates, nil without a value
  def distance(dates)
    values = cars.flat_map { |car| values_on(dates, car, :distance) }
    values.sum if values.any?
  end

  # The average of the daily maximum range of a car, nil without a value
  def max_range(car, dates)
    values = values_on(dates, car, :max_range)
    values.sum / values.size if values.any?
  end

  # The distance (km) of a car on a day, 0 without a value
  def daily_distance(car, date)
    summaries.dig([car.id, :distance], date) || 0.0
  end

  # The Sums of the sessions of a car on a day
  def daily_sessions(car, date)
    by_car_and_date.fetch([car.id, date], ChargingSession::Sums.empty)
  end

  private

  # The sum of the rows on the given dates for which the block is true
  def sum_rows(dates)
    ChargingSession::Sums.sum(rows_on(dates).filter_map { it.sums if yield(it) })
  end

  # The rows on the given dates. The rows are sorted by date, so a binary
  # search finds the first and the last of them.
  def rows_on(dates)
    first = rows.bsearch_index { it.date >= dates.begin } || rows.size
    last = rows.bsearch_index { it.date > dates.end } || rows.size
    rows[first...last]
  end

  # The rows of all days, sorted by date. A session belongs to the local date
  # of its start (see ChargingSession#date).
  def rows
    @rows ||=
      ChargingSession
        .where(car: cars)
        .or(ChargingSession.wallbox.where(car_id: nil))
        .on_dates(dates)
        .daily_sums
        .map { |(car_id, guest, date, kind), sums| Row.new(date:, car_id:, guest:, kind:, sums:) }
        .sort_by(&:date)
  end

  def by_car_and_date
    @by_car_and_date ||=
      rows.select(&:car_id).group_by { [it.car_id, it.date] }.transform_values { ChargingSession::Sums.sum(it.map(&:sums)) }
  end

  # The daily values of a car on the given dates
  def values_on(dates, car, key)
    summaries.fetch([car.id, key], {}).filter_map { |date, value| value if dates.cover?(date) }
  end

  SUMMARY_FIELDS = { car_odometer: %i[distance sum], car_max_range: %i[max_range avg] }.freeze
  private_constant :SUMMARY_FIELDS

  # { [car id, :distance or :max_range] => { date => value } }
  def summaries
    @summaries ||=
      begin
        fields =
          cars.each_with_object({}) do |car, result|
            SUMMARY_FIELDS.each { |role, (key, aggregation)| result[[car.sensor_name(role).to_s, aggregation.to_s]] = [car.id, key] }
          end

        SummaryValue
          .where(date: dates, field: fields.keys.map(&:first), aggregation: %w[sum avg])
          .pluck(:field, :aggregation, :date, :value)
          .each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |(field, aggregation, date, value), result|
            key = fields[[field, aggregation]]
            result[key][date] = value if key
          end
      end
  end
end
