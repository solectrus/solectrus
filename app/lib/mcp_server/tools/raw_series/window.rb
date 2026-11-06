module McpServer
  module Tools
    class RawSeries < Base
      # The window of a request, from `start`/`stop` or from a Timeframe
      module Window
        module_function

        # [start, stop], both on a whole second and stop not after now
        def for(start:, stop:, timeframe:)
          from, to =
            if timeframe
              raise ArgumentError, 'Give either `timeframe` or `start`/`stop`, not both.' if start.present? || stop.present?
              raise ArgumentError, 'Timeframe must cover a span, not the "now" instant.' if timeframe.now?

              [timeframe.beginning, timeframe.ending]
            elsif start.present?
              [parse(start, 'start'), stop.present? ? parse(stop, 'stop') : Time.current]
            else
              raise ArgumentError, 'Give `start` (an ISO 8601 timestamp) or a `timeframe`.'
            end

          clamp(from, to)
        end

        def parse(value, label)
          Time.zone.iso8601(value.to_s)
        rescue ArgumentError
          raise ArgumentError,
                "Invalid #{label}: #{value.inspect} is not an ISO 8601 timestamp " \
                  '(e.g. "2026-01-11T04:30:00Z"). Without an offset it is local time.'
        end

        # No collector writes earlier data. Before it, a year is anything that
        # ISO 8601 allows, and InfluxDB rejects the times it cannot store.
        EARLIEST = Time.utc(1970).freeze
        private_constant :EARLIEST

        # The window ends now at the latest: there is nothing to read beyond
        # it, and a fixed end keeps the probe and the read on the same data.
        def clamp(from, to)
          now = Time.current
          from = from.floor
          to = [to, now].min.ceil

          raise ArgumentError, '`start` lies in the future, so nothing has been measured yet.' if from >= now
          raise ArgumentError, '`start` must not be before 1970-01-01.' if from < EARLIEST
          raise ArgumentError, '`stop` must be after `start`.' if to <= from

          [from, to]
        end
      end
    end
  end
end
