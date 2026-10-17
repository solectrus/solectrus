# The rows of a list in groups of a month, a week or a day, by the start of
# each row (`started_at`). The length of the timeframe selects the period.
# Each group starts with a header (see Ui::GroupHeader::Component).
#
# `previous_started_at` is the start of the last row of the page before, so a
# group that goes on from there gets no second header. A row that starts
# before the timeframe goes in its first group.
class Ui::RowGroups
  include Enumerable

  def initialize(rows, timeframe:, previous_started_at: nil)
    @rows = rows
    @timeframe = timeframe
    @period = period_for(timeframe)
    @previous_started_at = previous_started_at
  end

  # Each row with the timeframe of the group that it starts, or with nil for a
  # row that continues the group of the row before
  def each(&) = @rows.zip(starts).each(&)

  private

  def starts
    [@previous_started_at, *@rows.map(&:started_at)]
      .map { it && Timeframe.of(date_of(it), @period) }
      .each_cons(2)
      .map { |before, group| group unless group.to_s == before.to_s }
  end

  def date_of(time)
    date = time.in_time_zone.to_date
    @timeframe.all? ? date : [date, @timeframe.effective_beginning_date].max
  end

  # The rows of a list longer than a month go in groups of a month, the rows
  # of a shorter list longer than a week in groups of a week, and the others
  # in groups of a day
  def period_for(timeframe)
    return :month if timeframe.all?

    case timeframe.ending.to_date - timeframe.beginning.to_date
    when 32.. then :month
    when 7.. then :week
    else :day
    end
  end
end
