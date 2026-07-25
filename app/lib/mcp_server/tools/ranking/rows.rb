module McpServer
  module Tools
    class Ranking < Base
      # Produces the ranked rows of a single sensor: the query itself, plus the
      # chronological presentation on top of it.
      module Rows
        module_function

        # [{ date:, value: }, ...], ordered by value or by date.
        def fetch(sensor, aggregation:, timeframe:, period:, desc:, chronological:, limit:) # rubocop:disable Metrics/ParameterLists
          rows =
            Sensor::Query::Ranking.new(
              sensor.name,
              aggregation:,
              period:,
              start: timeframe.effective_beginning_date,
              stop: timeframe.effective_ending_date,
              desc:,
              limit:,
            ).call
          return rows unless chronological

          with_gaps(rows.sort_by { |entry| entry[:date] }, period, limit)
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
