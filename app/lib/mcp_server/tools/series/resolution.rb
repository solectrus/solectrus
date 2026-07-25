module McpServer
  module Tools
    class Series < Base
      # Chooses the bucket resolution for a series request and reports whether a
      # client's explicitly requested resolution had to be coarsened.
      module Resolution
        module_function

        # Resolutions offered to the client, ascending, mapped to seconds.
        RESOLUTIONS = [
          ['1m', 60],
          ['5m', 300],
          ['15m', 900],
          ['1h', 3600],
          ['1d', 86_400],
        ].freeze
        private_constant :RESOLUTIONS

        # Hard cap on points across the WHOLE response, shared by all requested
        # sensors (every sensor returns the same bucket count). The resolution
        # is coarsened until the combined series fit within it.
        MAX_POINTS = 1500
        public_constant :MAX_POINTS

        # Forecast providers write one sample per forecast window, 15 minutes
        # at the finest (PVNode 15m, Solcast 30m, forecast.solar 60m). A bucket
        # below that is empty by construction.
        FORECAST_FLOOR = 900
        private_constant :FORECAST_FLOOR

        # The bucket to query, as [seconds, label].
        #
        # Exactly two things decide it: the shared point budget caps how fine it
        # can be, and forecast sensors put a floor under it. Both follow from
        # the request alone, never from the data that comes back - which is what
        # guarantees the monotonicity a client relies on: a coarser request can
        # never yield a coarser result than a finer one.
        def for(requested, timeframe, definitions)
          interval = within_budget(requested, timeframe, definitions.size)
          # One measured sensor in the request is enough to keep the fine grid:
          # the densest sensor decides.
          interval = [interval, FORECAST_FLOOR].max if definitions.all?(&:forecast?)

          RESOLUTIONS.rassoc(interval).reverse
        end

        # Whether an explicitly requested resolution was downgraded - by the
        # shared point budget or by the forecast floor - so a client never
        # assumes its requested resolution was honoured verbatim.
        def coarsened?(requested, used)
          requested.present? && used != requested
        end

        # Start at the requested resolution (or the finest when unset/unknown)
        # and coarsen until each sensor's series fits within its share of the
        # budget. Sharing MAX_POINTS across the `sensor_count` requested sensors
        # keeps an N-sensor request from overflowing the client by Nx, and
        # clamps an explicitly requested resolution too. Falls back to the
        # coarsest bucket for extreme spans.
        def within_budget(requested, timeframe, sensor_count)
          budget = [MAX_POINTS / sensor_count, 1].max
          span = (timeframe.ending - timeframe.beginning).to_i
          start = RESOLUTIONS.index { |label, _| label == requested } || 0

          entry = RESOLUTIONS[start..].find { |_label, secs| span.fdiv(secs).ceil <= budget }
          (entry || RESOLUTIONS.last).last
        end
      end
    end
  end
end
