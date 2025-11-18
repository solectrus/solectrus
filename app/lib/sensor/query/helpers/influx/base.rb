module Sensor
  module Query
    module Helpers
      module Influx
        class Base < Sensor::Query::Base
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
            { time: result[:time], payload: result.except(:time) }
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

          def query_with_time
            start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            result = yield
            end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            duration = end_time - start_time

            [result, duration]
          end

          def query_without_cache(string)
            result, duration =
              query_with_time { InfluxClient.query_api.query(query: string) }

            ActiveSupport::Notifications.instrument(
              'query.sensor_influx',
              class: self.class.name,
              query: string,
              sensors: @sensor_names,
              duration: duration,
            )

            result
          end

          # Build a short cache key from the query string to avoid hitting the 250 chars
          def cache_key(string)
            "sensor_influx:#{Digest::SHA256.hexdigest(string)}"
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
            available_sensors.find do |sensor|
              Sensor::Config.measurement(sensor) == measurement &&
                Sensor::Config.field(sensor) == field
            end
          end

          # Standard InfluxDB result parsing - can be used by subclasses
          def parse_flux_result(flux_result)
            result = {}

            flux_result.each do |table|
              table.records.each do |record|
                sensor =
                  find_sensor_by_measurement_and_field(
                    record.values['_measurement'],
                    record.values['_field'],
                  )

                next unless sensor

                result[sensor] = record.values['_value']

                # Get the latest time from all measurements
                # This is useful when the measurements are not in sync
                # The time is used to determine the "live" status of the system
                time = Time.zone.parse record.values['_time']
                result[:time] = time if result[:time].nil? ||
                  time > result[:time]
              end
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
