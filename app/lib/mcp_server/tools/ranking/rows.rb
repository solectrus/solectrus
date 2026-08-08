module McpServer
  module Tools
    class Ranking < Base
      # Produces the ranked rows of a single sensor: the query itself, plus the
      # chronological presentation on top of it.
      module Rows
        # How many periods lie between two period starts, per period type. The
        # ranked dates are period starts already (the SQL truncates them), so
        # counting them is exact rather than a division of elapsed seconds -
        # which months and years do not admit anyway.
        STEPS = {
          day: ->(from, to) { (to - from).to_i },
          week: ->(from, to) { (to - from).to_i / 7 },
          month: ->(from, to) { ((to.year * 12) + to.month) - ((from.year * 12) + from.month) },
          year: ->(from, to) { to.year - from.year },
        }.freeze
        private_constant :STEPS

        module_function

        # The ranking as an axis plus a list of values, in the shape
        # Series::Points uses for a curve and for the same reason: a `date` per
        # entry was most of the payload, and at the shared budget of 400 entries
        # it was the largest thing this tool could return.
        #
        # `start` is the first entry's period and `period` (echoed at the top
        # level) its width, so entry i covers start + i periods. `indices`
        # appears wherever that does not hold, which for a value ranking is
        # always - it is ordered by size, so its periods are not consecutive.
        def axis(rows, period)
          return { entry_count: 0, values: [] } if rows.empty?

          # The EARLIEST date, not the first entry: a value ranking is ordered
          # by size, so its first entry can sit anywhere in time and anchoring
          # there would hand out negative indices. Under sort="chronological"
          # the two are the same date anyway.
          start = rows.pluck(:date).min
          step = STEPS[period]
          indices = rows.map { |row| step.call(start, row[:date]) }
          partial_at = rows.each_index.select { rows[it][:partial] }

          {
            start: start.iso8601,
            entry_count: rows.size,
            **(indices.each_with_index.all? { |n, i| n == i } ? {} : { indices: }),
            **(partial_at.empty? ? {} : { partial_at: }),
            values: rows.pluck(:value),
          }
        end

        # [[{ date:, value:, partial: }, ...], complete_periods_only], the rows
        # ordered by value or by date. The flag travels with them because the
        # query answers a narrower question than it was asked whenever it is
        # set, and the response has to say so.
        def fetch(sensor, aggregation:, timeframe:, period:, desc:, chronological:, limit:) # rubocop:disable Metrics/ParameterLists
          query =
            Sensor::Query::Ranking.new(
              sensor.name,
              aggregation:,
              period:,
              start: timeframe.effective_beginning_date,
              stop: timeframe.effective_ending_date,
              desc:,
              limit:,
            )
          rows = query.call
          rows = with_gaps(rows.sort_by { |entry| entry[:date] }, period, limit) if chronological

          [mark_partial(rows, timeframe, period), query.complete_periods_only?]
        end

        # A ranked period is labelled with its START but summed over the days
        # inside the timeframe alone, so a period the timeframe cuts into is a
        # fragment under a label claiming the whole of it - and by its date
        # alone indistinguishable from the whole periods it competes with.
        # Mark it, so a client reads the value as the fragment it is.
        #
        # Both edges can be cut, and under a value ranking either can surface
        # anywhere in the list, so the marker travels with the row rather than
        # being implied by its position. The marker is set only where it
        # applies: its presence is the whole signal, and the common case stays
        # as cheap as it was.
        def mark_partial(rows, timeframe, period)
          rows.map do |entry|
            partial?(entry[:date], timeframe, period) ? entry.merge(partial: true) : entry
          end
        end

        # Two ways a period ends up a fragment. Either the timeframe cuts one
        # of its edges - measured against the dates the query itself ranked
        # over, not the timeframe's nominal ones.
        #
        # Or it holds today, which the timeframe bounds cannot express:
        # effective_ending_date is capped at today, so a period ending today
        # never looks cut by them - yet the day is not over. That is the
        # ordinary case for the default period="day", whose newest entry is a
        # few hours of measurement competing against whole days.
        def partial?(date, timeframe, period)
          ending = date + 1.public_send(period) - 1.day

          date < timeframe.effective_beginning_date ||
            ending > timeframe.effective_ending_date || ending >= Date.current
        end

        # A period without data has no summary row, so it drops out of the
        # ranking silently - in a chronological list that leaves an invisible
        # hole, indistinguishable from a period whose value happened to be 0
        # until the client diffs the dates itself. Report those periods with an
        # explicit null instead.
        #
        # Only the holes between the first and the last entry are filled: what
        # lies outside is not a gap but the edge of the data, and padding a
        # full year of empty days around a handful of entries helps nobody.
        #
        # A list truncated by the limit is left alone - a period missing from a
        # top-N selection may simply not have made the cut, and a null would
        # claim it has no data.
        def with_gaps(rows, period, limit)
          return rows if rows.size < 2 || rows.size >= limit

          by_date = rows.index_by { |entry| entry[:date] }
          dates = period_range(rows.first[:date], rows.last[:date], period)
          dates |= by_date.keys
          dates.sort!

          dates.map { |date| by_date[date] || { date:, value: nil } }
        end

        # Every period start from `first` to `last`. Ranked dates are period
        # starts already (the SQL truncates them), so stepping by one period
        # stays aligned with them.
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
  end
end
