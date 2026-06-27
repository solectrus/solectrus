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
        public_constant :RESOLUTIONS

        # Hard cap on points across the WHOLE response, shared by all requested
        # sensors (every sensor returns the same bucket count). The resolution
        # is coarsened until the combined series fit within it.
        MAX_POINTS = 1500
        public_constant :MAX_POINTS

        # Pick the bucket: start at the requested resolution (or the finest when
        # unset/unknown) and coarsen until each sensor's series fits within its
        # share of the budget. Sharing MAX_POINTS across the `sensor_count`
        # requested sensors keeps an N-sensor request from overflowing the
        # client by Nx, and clamps an explicitly requested resolution too.
        # Falls back to the coarsest bucket for extreme spans.
        def for(requested, timeframe, sensor_count)
          budget = [MAX_POINTS / sensor_count, 1].max
          span = (timeframe.ending - timeframe.beginning).to_i
          start = RESOLUTIONS.index { |label, _| label == requested } || 0

          RESOLUTIONS[start..]
            .find { |_label, secs| span.fdiv(secs).ceil <= budget }
            &.reverse || RESOLUTIONS.last.reverse
        end

        # Whether an explicitly requested resolution was downgraded - by the
        # shared point budget or by cadence-snapping - so a client never assumes
        # its requested resolution was honoured verbatim.
        def coarsened?(requested, used)
          requested.present? && used != requested
        end
      end
    end
  end
end
