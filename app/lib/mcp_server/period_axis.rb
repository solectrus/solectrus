module McpServer
  # The axis get_ranking and get_periods both answer on: a list of calendar
  # periods stated once as a `start` plus the `period` it steps in, with a bare
  # `values` list under it rather than one dated object per entry.
  #
  # It lives outside both tools because it is neither's: a `date` per entry was
  # most of what either response cost, and the arithmetic that replaced it -
  # how many months lie between two month starts, whether a period is cut by
  # the range - is the same arithmetic for a top-10 list and for a curve. The
  # two tools disagree about which periods to return, never about how to
  # describe where one sits.
  module PeriodAxis
    # How many periods lie between two period starts, per period type. The
    # dates are period starts already (the SQL truncates them), so counting
    # them is exact rather than a division of elapsed seconds - which months
    # and years do not admit anyway.
    STEPS = {
      day: ->(from, to) { (to - from).to_i },
      week: ->(from, to) { (to - from).to_i / 7 },
      month: ->(from, to) { ((to.year * 12) + to.month) - ((from.year * 12) + from.month) },
      year: ->(from, to) { to.year - from.year },
    }.freeze
    private_constant :STEPS

    module_function

    # How many periods of this width a timeframe covers, countable BEFORE any
    # query runs - which is what lets get_periods refuse a request it cannot
    # answer within its budget instead of answering a truncated one.
    #
    # Measured against the effective bounds, so it never counts a period before
    # the installation or after today: those hold no data and would be padded
    # with nulls that say nothing.
    def period_count(timeframe, period)
      first = period_start(timeframe.effective_beginning_date, period)
      last = period_start(timeframe.effective_ending_date, period)

      STEPS[period].call(first, last) + 1
    end

    # The coercion is load-bearing: beginning_of_week/month/year return a Date,
    # beginning_of_DAY a Time. Without it the day case counts in seconds - a
    # three-day range came back as 172801 periods - and the same mismatch once
    # cost every day-ranking its first and last day (Sensor::Query::Ranking,
    # #5789).
    def period_start(date, period)
      date.public_send("beginning_of_#{period}").to_date
    end

    # The rows as an axis plus a list of values.
    #
    # `start` is the EARLIEST period, not the first entry: a value ranking is
    # ordered by size, so its first entry can sit anywhere in time and
    # anchoring there would hand out negative indices. Read chronologically the
    # two are the same date anyway.
    #
    # `indices` appears wherever entry i is not at offset i - always for a
    # value ranking, never for a chronological list, which is dense by
    # construction.
    def axis(rows, period)
      return { entry_count: 0, values: [] } if rows.empty?

      start = rows.pluck(:date).min
      step = STEPS[period]
      indices = rows.map { |row| step.call(start, row[:date]) }

      # By period START, not by position in `values`. A position would be a
      # second index space next to `indices` - which counts PERIODS from
      # `start` - and under a value ranking the two disagree: with indices
      # [1, 0, 2] a partial_at of [1, 2] names the first and second entry
      # while reading as the second and third period. A date belongs to no
      # index space at all.
      partial_at = rows.filter_map { it[:date].iso8601 if it[:partial] }

      {
        start: start.iso8601,
        entry_count: rows.size,
        **(indices.each_with_index.all? { |n, i| n == i } ? {} : { indices: }),
        **(partial_at.empty? ? {} : { partial_at: }),
        values: rows.pluck(:value),
      }
    end

    # A period is labelled with its START but aggregated over the days inside
    # the timeframe alone, so a period the timeframe cuts into is a fragment
    # under a label claiming the whole of it - and by its date alone
    # indistinguishable from the whole periods beside it. Mark it, so a client
    # reads the value as the fragment it is.
    #
    # Both edges can be cut, and under a value ranking either can surface
    # anywhere in the list, so the marker travels with the row rather than
    # being implied by its position. It is set only where it applies: its
    # presence is the whole signal, and the common case stays cheap.
    def mark_partial(rows, timeframe, period)
      rows.map do |entry|
        partial?(entry[:date], timeframe, period) ? entry.merge(partial: true) : entry
      end
    end

    # Two ways a period ends up a fragment. Either the timeframe cuts one of
    # its edges - measured against the dates the query actually read over, not
    # the timeframe's nominal ones.
    #
    # Or it holds today, which the timeframe bounds cannot express:
    # effective_ending_date is capped at today, so a period ending today never
    # looks cut by them - yet the day is not over. That is the ordinary case
    # for period="day", whose newest entry is a few hours of measurement
    # standing next to whole days.
    def partial?(date, timeframe, period)
      ending = date + 1.public_send(period) - 1.day

      date < timeframe.effective_beginning_date ||
        ending > timeframe.effective_ending_date || ending >= Date.current
    end

    # Every period start from `first` to `last`. The dates are period starts
    # already, so stepping by one period stays aligned with them.
    def period_range(first, last, period)
      step = 1.public_send(period)

      [].tap do |dates|
        date = first
        while date <= last
          dates << date
          date += step
        end
      end
    end
  end
end
