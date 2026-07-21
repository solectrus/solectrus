module Sensor
  module Query
    module Helpers
      module Influx
        class Base < Sensor::Query::Base
          # Part of the cache key, to be bumped whenever the shape of a cached
          # result changes. Without it a deploy keeps serving entries written
          # by the previous format, and #cache_options caches a past timeframe
          # indefinitely - so such an entry outlives every TTL and breaks the
          # page until Redis is flushed by hand.
          #
          # 2: Influx::CsvParser replaced InfluxDB2::FluxTable objects with
          #    plain row hashes.
          CACHE_VERSION = 2
          private_constant :CACHE_VERSION

          def initialize(sensor_names, timeframe)
            super
            @cache_options = default_cache_options
          end

          protected

          def fetch_raw_data
            return empty_result if available_sensors.empty?

            flux_query = build_flux_query
            flux_result = query(flux_query)

            result = parse_flux_result(flux_result)
            {
              time: result[:time],
              times: result[:times] || {},
              payload: result.except(:time, :times),
            }
          end

          private

          def from_bucket
            "from(bucket: \"#{Rails.configuration.x.influx.bucket}\")"
          end

          def filter(selected_sensors: available_sensors)
            # Group sensors by their measurement
            grouped =
              selected_sensors.each_with_object(
                Hash.new { |h, k| h[k] = [] },
              ) do |sensor, result|
                measurement = Sensor::Config.measurement(sensor)
                field = Sensor::Config.field(sensor)
                result[measurement] << field if measurement && field
              end

            return 'filter(fn: (r) => false)' if grouped.empty?

            # Generate filter conditions
            filter_conditions =
              grouped.map do |measurement, fields|
                field_conditions =
                  fields
                    .map { |field| "r[\"_field\"] == \"#{field}\"" }
                    .join(' or ')

                "r[\"_measurement\"] == \"#{measurement}\" and (#{field_conditions})"
              end

            # Combine all conditions into the final filter string
            "filter(fn: (r) => #{filter_conditions.join(' or ')})"
          end

          def range(start:, stop: nil)
            @cache_options = cache_options(stop:)

            start = start&.iso8601
            stop = stop&.iso8601

            if stop
              "range(start: #{start}, stop: #{stop})"
            else
              "range(start: #{start})"
            end
          end

          def query(string)
            return query_without_cache(string) unless @cache_options

            Rails
              .cache
              .fetch(cache_key(string), **@cache_options) do
                query_without_cache(string)
              end
          end

          # Instrumenting *around* the call is what gives the event a duration -
          # emitting it afterwards would leave every subscriber reading
          # `event.duration` (APM tooling, for one) with a flat zero.
          def query_without_cache(string)
            ActiveSupport::Notifications.instrument(
              'query.sensor_influx',
              class: self.class.name,
              query: string,
              sensors: @sensor_names,
            ) { ::Influx.query(string) }
          end

          # Build a short cache key from the query string to avoid hitting the 250 chars
          def cache_key(string)
            "sensor_influx:v#{CACHE_VERSION}:#{Digest::SHA256.hexdigest(string)}"
          end

          def cache_options(stop:)
            # Cache forever if the result cannot change anymore
            return {} if stop&.past?

            default_cache_options
          end

          # Default cache options, can be overridden in subclasses
          def default_cache_options
            return if @timeframe.nil? || @timeframe.now? || @timeframe.hours?

            { expires_in: 3.minutes }
          end

          def find_sensor_by_measurement_and_field(measurement, field)
            sensor_lookup[[measurement, field]]
          end

          def sensor_lookup
            @sensor_lookup ||= available_sensors.index_by do |sensor|
              [Sensor::Config.measurement(sensor), Sensor::Config.field(sensor)]
            end
          end

          # Standard InfluxDB result parsing - can be used by subclasses
          def parse_flux_result(flux_result)
            result = { times: {} }

            flux_result.each do |record|
              sensor =
                find_sensor_by_measurement_and_field(
                  record['_measurement'],
                  record['_field'],
                )

              next unless sensor

              result[sensor] = record['_value']

              # Track per-sensor timestamp (used to detect stale "latest" values)
              # and the overall newest time across all sensors (used for the
              # adaptive poll-interval estimator and live-status indicators).
              time = Time.zone.parse record['_time']
              result[:times][sensor] = time
              result[:time] = time if result[:time].nil? || time > result[:time]
            end

            result
          end

          def query_type
            :influx
          end
        end
      end
    end
  end
end
