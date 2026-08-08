module McpServer
  module Tools
    class Series < Base
      # Chooses the bucket resolution for a series request and reports whether a
      # client's explicitly requested resolution had to be coarsened.
      module Resolution
        module_function

        # Resolutions offered to the client, ascending, mapped to seconds.
        #
        # It ends at "1h" because Series::MAX_SPAN ends the tool at 99 hours: a
        # daily bucket would hold four points at most, and a value per day is
        # what get_ranking reads from the summaries - exactly, rather than as
        # the mean of whatever samples the day happened to carry.
        RESOLUTIONS = [['1m', 60], ['5m', 300], ['15m', 900], ['1h', 3600]].freeze
        private_constant :RESOLUTIONS

        # The labels the input schema publishes, taken from the ladder itself.
        #
        # They used to be a second list, spelled out in Series' input_schema,
        # with nothing keeping the two in step. A label the ladder does not
        # carry falls through the lookup below to index 0, so the request comes
        # back at the FINEST bucket instead of being refused - 288 points where
        # 24 were asked for, reported as coarsened by the point budget, with
        # advice to shorten a timeframe that was never the problem.
        LABELS = RESOLUTIONS.map(&:first).freeze
        public_constant :LABELS

        # Hard cap on points across the WHOLE response, shared by all requested
        # sensors (every sensor returns the same bucket count). The resolution
        # is coarsened until the combined series fit within it.
        #
        # A point costs about 6 bytes (measured, see
        # spec/lib/mcp_server/payload_size_spec.rb): the axis is stated once,
        # so a point is the value and nothing else. It was ~50 bytes while
        # every point carried its own ISO timestamp, and 400 was set against
        # THAT price - the budget outlived the format it was priced for, and
        # went on refusing at 2.3 kB what it had been meant to refuse at 20 kB.
        #
        # 1440 is a full day at "1m", the finest bucket the ladder offers -
        # the natural ceiling of a question this tool answers, and one a client
        # asks ("the minute curve of yesterday") and used to get silently
        # coarsened to 5m. It costs ~8 kB for one sensor, still under half of
        # what the old budget cost at the old price.
        #
        # It stays a context-window budget rather than a transfer one: what
        # reaches the client is one context, not one per sensor, which is why
        # the sensors share it.
        MAX_POINTS = 1440
        public_constant :MAX_POINTS

        # Forecast providers write one sample per forecast window, 15 minutes
        # at the finest (PVNode 15m, Solcast 30m, forecast.solar 60m). A bucket
        # below that is empty by construction.
        FORECAST_FLOOR = 900
        private_constant :FORECAST_FLOOR

        # Facts::SPLIT_CADENCE, as a floor: a bucket below the splitter cycle
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
          validate!(requested)
          span = billable_span(timeframe, definitions, include_nulls)
          budgeted = within_budget(requested, span, definitions.size)
          raise ArgumentError, over_budget(span, definitions) unless budgeted

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

        # A resolution outside the ladder, refused by name.
        #
        # The schema rejects it first, so this is the backstop for a client
        # working from a cached schema - and "1d" was a valid label until this
        # tool was bounded to 99 hours, so those clients exist. Refusing beats
        # guessing: the guess this replaced returned the finest bucket for the
        # coarsest request, which is the one answer that can blow up a context
        # window while looking like an ordinary reply.
        def validate!(requested)
          return if requested.blank? || LABELS.include?(requested)

          raise ArgumentError,
                "Unknown resolution \"#{requested}\". Use one of: " \
                  "#{LABELS.join(', ')}. A bucket coarser than \"1h\" is a " \
                  'summary question - get_ranking(sort: "chronological") ' \
                  'reads a value per day, week, month or year from the ' \
                  'summaries, exact per period rather than a mean per bucket.'
        end

        # Start at the requested resolution (or the finest when unset) and
        # coarsen until each sensor's series fits within its share of the
        # budget. Sharing MAX_POINTS across the `sensor_count` requested sensors
        # keeps an N-sensor request from overflowing the client by Nx, and
        # clamps an explicitly requested resolution too. Returns nil where not
        # even the coarsest bucket fits.
        #
        # `requested` is known to be a valid label or blank by now (validate!),
        # so the lookup cannot miss - which is what makes starting at index 0
        # mean "nothing was asked for" rather than "something unrecognized was".
        def within_budget(requested, span, sensor_count)
          budget = per_sensor_budget(sensor_count)
          start = requested.blank? ? 0 : LABELS.index(requested)

          entry = RESOLUTIONS[start..].find { |_label, secs| span.fdiv(secs).ceil <= budget }
          entry&.last
        end

        # What one sensor may spend, MAX_POINTS being shared by all of them.
        def per_sensor_budget(sensor_count)
          [MAX_POINTS / sensor_count, 1].max
        end

        # The one request the ladder cannot answer: at "1h", its coarsest
        # bucket, the series still exceeds the budget, and there is no coarser
        # step to escape to.
        #
        # It used to be answered anyway - the ladder fell back to its last
        # entry without checking that the entry fit - and that broke the budget
        # silently, with `coarsened: false`, because nothing HAD been coarsened:
        # the ladder had simply run out. "all" on a system running since 2020
        # came back as 2080 points that way.
        #
        # Two requests reach it now that Series::MAX_SPAN caps the timeframe:
        # more sensors than the budget can carry over the window asked for, and
        # a forecast-only request, which is exempt from that cap. Both are
        # rejected rather than answered over budget, because the alternative -
        # a truncated series - answers a different question than the one asked:
        # a curve cut to its first 400 points still plots as a whole one.
        def over_budget(span, definitions)
          hours = span.fdiv(RESOLUTIONS.last.last).ceil
          budget = per_sensor_budget(definitions.size)

          "This request needs #{hours} points per sensor at \"1h\", the " \
            "coarsest bucket get_series offers, above the #{budget} it may " \
            "spend#{shared_budget(definitions.size)}. Ask for at most " \
            "#{budget} hours at this sensor count, or for fewer sensors." \
            "#{forecast_hint(definitions)}"
        end

        def shared_budget(sensor_count)
          return '' if sensor_count == 1

          " (#{MAX_POINTS} shared by #{sensor_count} sensors)"
        end

        # A forecast-only request is the one that can reach the budget with a
        # single sensor, and shortening its timeframe is rarely what the client
        # wanted - it asked for a horizon.
        def forecast_hint(definitions)
          return '' unless definitions.all?(&:forecast?)

          ' get_forecast reports the expected energy per day without a curve.'
        end
      end
    end
  end
end
