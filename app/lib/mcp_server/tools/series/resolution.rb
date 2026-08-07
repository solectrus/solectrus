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
        #
        # A point costs about 50 bytes / 34 tokens (measured, see
        # spec/lib/mcp_server/payload_size_spec.rb), most of it the ISO
        # timestamp. That is what makes this budget a context-window budget
        # rather than a transfer one: at 1500 points a single response was
        # ~51k tokens, a quarter of a typical context.
        #
        # 400 is the smallest round number that still keeps the canonical
        # request - one sensor over one day - at 5m (288 points), with enough
        # headroom that a change to the resolution ladder does not silently
        # cost a whole step. A month then answers at 1d rather than 1h, which
        # is the right trade: for a month, get_totals and get_ranking are the
        # tools, not a 720-point curve.
        #
        # This is the MCP budget only. The web UI does not go through this
        # module; it drives Sensor::Query::Series with its own interval.
        MAX_POINTS = 400
        public_constant :MAX_POINTS

        # Forecast providers write one sample per forecast window, 15 minutes
        # at the finest (PVNode 15m, Solcast 30m, forecast.solar 60m). A bucket
        # below that is empty by construction.
        FORECAST_FLOOR = 900
        private_constant :FORECAST_FLOOR

        # The Power Splitter recomputes the grid/PV division on its own cycle of
        # several minutes and writes one value per cycle. A bucket below that
        # carries a value in some buckets and nothing in the rest, which reads
        # as an outage rather than as the cadence it is.
        SPLITTER_FLOOR = 300
        private_constant :SPLITTER_FLOOR

        # The bucket to query, as [seconds, label, coarsened_by].
        #
        # Three things decide it: the shared point budget caps how fine it can
        # be, and forecast sensors and power splits each put a floor under it.
        # All follow from the request alone, never from the data that comes back
        # - which is what guarantees the monotonicity a client relies on: a
        # coarser request can never yield a coarser result than a finer one.
        def for(requested, timeframe, definitions, include_nulls: true)
          span = billable_span(timeframe, definitions, include_nulls)
          budgeted = within_budget(requested, span, definitions.size)
          floor = floor_for(definitions)
          interval = [budgeted, floor].max
          label = RESOLUTIONS.rassoc(interval).first

          [interval, label, coarsened_by(requested, label, interval, floor, definitions)]
        end

        # The coarsest cadence among the requested sensors, or none when a
        # densely written one is in the request: one measured sensor is enough
        # to keep the fine grid, because the densest sensor decides what the
        # shared bucket grid is worth.
        def floor_for(definitions)
          return FORECAST_FLOOR if definitions.all?(&:forecast?)
          return SPLITTER_FLOOR if definitions.none?(&:instantaneous?)

          0
        end

        # Which of the three constraints downgraded an explicitly requested
        # resolution, or nil when none did - so a client never assumes its
        # requested resolution was honoured verbatim, and the response can name
        # something the client can act on rather than a bare boolean.
        #
        # The budget only explains the answer where it lands STRICTLY coarser
        # than the floor. Where both would settle on the same bucket - a split
        # over a past day is exactly that case at the shipped budget - the
        # floor is the one to name: it is the constraint that cannot be traded
        # against, so naming the budget sends a client off to shorten a
        # timeframe that will land on the same bucket again.
        #
        # An auto-selected resolution (no `requested`) is never "coarsened":
        # there was nothing to honour.
        def coarsened_by(requested, label, interval, floor, definitions)
          return if requested.blank? || label == requested
          return :point_budget if interval > floor

          definitions.all?(&:forecast?) ? :forecast_window : :splitter_cycle
        end

        # The `coarsened_reason` field, as a hash to splat into the response -
        # empty when nothing was coarsened, so the field only exists when it
        # has something to say.
        #
        # A bare `coarsened: true` tells a client that something happened but
        # not what to do about it, and the two constraints differ in exactly
        # that: a point budget can be traded against (fewer sensors, a shorter
        # timeframe), a provider's forecast cadence cannot.
        def explain(coarsened_by, requested, label, sensor_count)
          case coarsened_by
          when :point_budget
            {
              coarsened_reason:
                "Requested #{requested}, returning #{label}: #{sensor_count} sensor(s) " \
                  "share a budget of #{MAX_POINTS} points. Request fewer sensors or a " \
                  'shorter timeframe for a finer curve.',
            }
          when :forecast_window
            {
              coarsened_reason:
                "Requested #{requested}, returning #{label}: forecast providers write " \
                  'at most one sample per 15 minutes, so a finer grid would be almost ' \
                  'entirely null. This is as fine as forecast data gets.',
            }
          when :splitter_cycle
            {
              coarsened_reason:
                "Requested #{requested}, returning #{label}: the Power Splitter writes " \
                  'one value per cycle of several minutes, so a finer grid would leave ' \
                  'most buckets empty. This is as fine as a power split gets, and no ' \
                  'shorter timeframe changes it.',
            }
          else
            {}
          end
        end

        # The part of the timeframe that can produce a point, which is what the
        # budget has to cover - not the timeframe itself.
        #
        # They differ for the running period: asking for today at 08:00 spans 24
        # hours, but 16 of them lie ahead and hold nothing. With
        # include_nulls: false those buckets are dropped before the client ever
        # sees them, so charging the budget for them coarsened the answer for
        # points that were never sent - three sensors over today fell from 5m to
        # 1h at breakfast and recovered by midnight.
        #
        # Only with include_nulls: false, where the empty tail really does
        # vanish, and never with a forecast sensor in the request, whose whole
        # point is that its future buckets carry values.
        def billable_span(timeframe, definitions, include_nulls)
          span = (timeframe.ending - timeframe.beginning).to_i
          return span if include_nulls || definitions.any?(&:forecast?)

          (Time.current - timeframe.beginning).to_i.clamp(1, span)
        end

        # Start at the requested resolution (or the finest when unset/unknown)
        # and coarsen until each sensor's series fits within its share of the
        # budget. Sharing MAX_POINTS across the `sensor_count` requested sensors
        # keeps an N-sensor request from overflowing the client by Nx, and
        # clamps an explicitly requested resolution too. Falls back to the
        # coarsest bucket for extreme spans.
        def within_budget(requested, span, sensor_count)
          budget = [MAX_POINTS / sensor_count, 1].max
          start = RESOLUTIONS.index { |label, _| label == requested } || 0

          entry = RESOLUTIONS[start..].find { |_label, secs| span.fdiv(secs).ceil <= budget }
          (entry || RESOLUTIONS.last).last
        end
      end
    end
  end
end
