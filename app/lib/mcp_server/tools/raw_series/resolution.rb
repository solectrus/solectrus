module McpServer
  module Tools
    class RawSeries < Base
      # The window size and the point budget of an aggregated request. The
      # budget follows from the request and the series it hits, never from how
      # densely they were written, so a coarser request never fails where a
      # finer one passed. The budget of the samples themselves counts them
      # (see RawSeries.read_samples).
      module Resolution
        module_function

        # Label => seconds, ascending. No day: a window aligns to UTC (see
        # Influx::RawQuery#windows), and a day would not start at local
        # midnight.
        LADDER = {
          '10s' => 10,
          '30s' => 30,
          '1m' => 60,
          '5m' => 300,
          '10m' => 600,
          '15m' => 900,
          '30m' => 1800,
          '1h' => 3600,
          '6h' => 21_600,
        }.freeze
        private_constant :LADDER

        LABELS = LADDER.keys.freeze
        public_constant :LABELS

        # [seconds, label]. Without `requested`, the finest that fits the
        # budget. RawSeries has checked the label already.
        def for(requested, span, tables)
          label = requested || finest(span, tables) || LABELS.last
          seconds = LADDER[label]
          raise ArgumentError, over_budget(label, span, tables) unless fits?(span, seconds, tables)

          [seconds, label]
        end

        # The windows each series cuts the span into: an unaligned span cuts
        # one more
        def points(span, seconds, tables) = ((span / seconds).ceil + 1) * tables

        def fits?(span, seconds, tables) = points(span, seconds, tables) <= MAX_POINTS

        # The finest resolution that fits, or nil
        def finest(span, tables) = LABELS.find { fits?(span, LADDER[it], tables) }

        def over_budget(label, span, tables)
          finest = finest(span, tables)

          "At resolution \"#{label}\" this request returns up to " \
            "#{points(span, LADDER[label], tables)} points (#{tables} field series), more " \
            "than #{MAX_POINTS}. " +
            if finest
              "Use resolution \"#{finest}\", a shorter window or fewer fields."
            else
              'Ask for fewer fields, narrow the series with `tags`, or shorten the window.'
            end
        end
      end
    end
  end
end
