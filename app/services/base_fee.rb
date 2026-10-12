# The monthly base fee of the electricity tariff, spread over the days it
# covers: one day carries the monthly amount divided by the length of its month,
# so a full month adds up to exactly the monthly amount and a partial month
# prorates by day.
#
# Each price record defines the complete tariff for its validity window, so a
# record without amount_per_month means "no base fee" from that date on.
#
# The SQL backend says the same in one column of the daily CTE (see
# Sensor::Query::Helpers::Sql::CteBuilder#base_fee_column). This is its
# counterpart for the InfluxDB paths, which have no prices table to join.
class BaseFee
  # The fee that falls on a timeframe.
  def self.for(timeframe)
    new(timeframe).amount
  end

  # The same fee as a rate per hour, for a query whose data points are power
  # readings rather than energy.
  def self.per_hour(timeframe)
    new(timeframe).per_hour
  end

  # Whether the tariff carries a base fee at all. A caller that splits a value
  # into fee and energy asks this first: without a fee there is nothing to
  # split off, and a second segment would stay empty at every point.
  def self.any?(schedule = fee_schedule)
    schedule.any? { |_, monthly| monthly&.positive? }
  end

  # Every electricity record, newest first: the first one starting on or before
  # a date is the one that applies. Records without an amount are kept, because
  # a newer record without a base fee cancels an older one that had one.
  def self.fee_schedule
    Price.list_for(:electricity).pluck(:starts_at, :amount_per_month)
  end

  def initialize(timeframe)
    @timeframe = timeframe
  end

  # A day the window only touches counts by the fraction it covers, so two
  # adjacent windows never bill it twice.
  #
  # Measured on the window, not on the days the timeframe is named after: P4D
  # carries the name of today but ends yesterday, and a window crossing a month
  # boundary holds days of two months, which carry different shares of the
  # monthly amount.
  def amount
    return 0 unless any_fee?

    (from.to_date..to.to_date).sum do |date|
      covered = [to, date.end_of_day].min - [from, date.beginning_of_day].max
      fee_on(date) * covered / 1.day.to_i
    end
  end

  # Spread over the very window #amount was measured on, so the points of a
  # chart add up to the fee that falls on the part of it they cover.
  def per_hour
    return 0 unless any_fee?

    hours = (to - from) / 1.hour.to_i
    hours.positive? ? amount / hours : 0
  end

  private

  attr_reader :timeframe

  def from
    @from ||= timeframe.beginning
  end

  def to
    @to ||= timeframe.ending
  end

  # No base fee anywhere in the history means every day is zero, and answering
  # that from the schedule alone skips the day walk - the common case, on every
  # render of the stats page.
  def any_fee?
    from && to && self.class.any?(schedule)
  end

  def fee_on(date)
    monthly = schedule.find { |starts_at, _| starts_at <= date }&.last
    return 0 unless monthly

    # Not date.end_of_month.day: this runs once per day of the window, and the
    # lookup allocates no Date.
    monthly / Time.days_in_month(date.month, date.year)
  end

  def schedule
    @schedule ||= self.class.fee_schedule
  end
end
