module McpServer
  module Tools
    class Ranking < Base
      # Produces the ranked rows of a single sensor: the query, plus the flag
      # the response has to carry with them.
      #
      # Where a row sits on the axis is not here - that is McpServer::
      # PeriodAxis, which get_periods answers on as well.
      module Rows
        module_function

        # [[{ date:, value:, partial: }, ...], complete_periods_only], the rows
        # ordered by value. The flag travels with them because the query
        # answers a narrower question than it was asked whenever it is set, and
        # the response has to say so.
        def fetch(sensor, aggregation:, timeframe:, period:, desc:, limit:)
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

          [
            PeriodAxis.mark_partial(query.call, timeframe, period),
            query.complete_periods_only?,
          ]
        end
      end
    end
  end
end
