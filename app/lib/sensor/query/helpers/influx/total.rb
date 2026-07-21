module Sensor
  module Query
    module Helpers
      module Influx
        # Calculates statistics for hourly timeframes (P1H-P99H) directly from InfluxDB
        # Supports DSL configuration with different aggregations per sensor
        #
        # Compatible with Sensor::Query::Sql DSL - accepts optional base_aggregation parameter
        #
        # Usage:
        #   # Simple sum for power sensors (integral calculation)
        #   query = Sensor::Query::Helpers::Influx::Total.new(Timeframe.new('P24H')) do |q|
        #     q.sum :house_power              # Short syntax
        #     q.sum :grid_import_power, :sum  # Explicit syntax (SQL DSL compatible)
        #   end
        #   data = query.call
        #   data.house_power  # => 15000.0 (Wh)
        #
        #   # Multiple sensors with different aggregations
        #   query = Sensor::Query::Helpers::Influx::Total.new(Timeframe.new('P24H')) do |q|
        #     q.sum :house_power      # Integral for power sensors
        #     q.avg :case_temp        # Average for temperature
        #     q.max :battery_soc      # Maximum for battery SOC
        #   end
        #   data = query.call
        #   data.house_power  # => 15000.0
        #   data.case_temp    # => 23.5
        #   data.battery_soc  # => 95.0
        class Total < Base
          include FinanceCalculation

          def initialize(timeframe, &block)
            unless block
              raise ArgumentError, 'Block required for DSL configuration'
            end

            # Validate timeframe
            validate_hourly_timeframe!(timeframe)

            # Build DSL configuration using helper
            sensor_requests = build_dsl_configuration(&block)

            # Automatically resolve dependencies for calculated sensors
            sensor_requests = resolve_dependencies(sensor_requests)

            # Initialize parent with extracted sensor names
            sensor_names = sensor_requests.map(&:first)
            super(sensor_names, timeframe)

            # Store configuration
            @sensor_requests = sensor_requests
          end

          attr_reader :sensor_requests

          protected

          def create_data_instance(raw_data, timeframe)
            Sensor::Data::Single.new(raw_data[:payload], timeframe:)
          end

          private

          # Build DSL configuration from block
          def build_dsl_configuration(&)
            builder = Influx::DslBuilder.new
            yield(builder)
            builder.sensor_requests
          end

          # Automatically resolve dependencies for calculated sensors
          # Uses DependencyResolver to get all required sensors in correct order
          def resolve_dependencies(sensor_requests)
            sensor_names = sensor_requests.map(&:first)

            # Use DependencyResolver to get all sensors including dependencies
            resolver = Sensor::DependencyResolver.new(sensor_names, context: query_type)
            all_sensor_names = resolver.resolve

            # Build aggregation map from original requests
            # sensor_requests format: [sensor_name, aggregation, base_aggregation]
            aggregation_map = sensor_requests.to_h { |req| [req.first, req[1]] }
            base_aggregation_map = sensor_requests.to_h { |req| [req.first, req[2]] }

            # Map all sensors to requests with appropriate aggregations
            all_sensor_names.map do |sensor_name|
              aggregation = aggregation_map[sensor_name] || :sum
              base_aggregation = base_aggregation_map[sensor_name] || aggregation
              [sensor_name, aggregation, base_aggregation]
            end
          end

          def validate_hourly_timeframe!(timeframe)
            return if timeframe&.hours?

            raise ArgumentError,
                  'Timeframe must be an hourly timeframe (P1H-P99H)'
          end

          # Group sensor requests by base aggregation type for efficient Flux queries
          # Only include sensors that are stored in InfluxDB (not calculated)
          # Sensors with same base_aggregation can be queried together
          def group_requests_by_aggregation
            @sensor_requests
              .reject { |sensor_name, _, _| sensor_is_calculated?(sensor_name) }
              .group_by { |_, _, base_agg| base_agg }
          end

          def sensor_is_calculated?(sensor_name)
            Sensor::Config.measurement(sensor_name).nil?
          end

          def build_flux_query
            # Group sensors by their aggregation type
            grouped = group_requests_by_aggregation

            # Return empty result if no InfluxDB sensors requested
            return empty_flux_query if grouped.empty?

            # Build individual queries for each aggregation type
            queries =
              grouped.map do |aggregation, requests|
                build_aggregation_query(aggregation, requests)
              end

            # Combine all queries with union
            return queries.first if queries.size == 1

            query_definitions =
              queries.each_with_index.map { |query, i| "query#{i} = #{query}" }
            query_names = Array.new(queries.size) { |i| "query#{i}" }

            <<~FLUX
              #{query_definitions.join("\n\n")}

              union(tables: [#{query_names.join(', ')}])
                |> group()
            FLUX
          end

          def empty_flux_query
            # Return a query that returns no results
            <<~FLUX
              #{from_bucket}
                |> range(start: #{timeframe.beginning.iso8601})
                |> filter(fn: (r) => false)
            FLUX
          end

          def build_aggregation_query(aggregation, requests)
            sensor_names = requests.map(&:first)
            flux_function = aggregation_flux_function(aggregation)

            <<~FLUX
              #{from_bucket}
                |> #{range(start: timeframe.beginning, stop: timeframe.ending)}
                |> #{filter(selected_sensors: sensor_names)}
                |> #{flux_function}
                |> set(key: "aggregation", value: "#{aggregation}")
            FLUX
          end

          AGGREGATION_FUNCTIONS = {
            sum: 'integral(unit: 1h)',
            avg: 'mean()',
            min: 'min()',
            max: 'max()',
          }.freeze
          private_constant :AGGREGATION_FUNCTIONS

          def aggregation_flux_function(aggregation)
            AGGREGATION_FUNCTIONS[aggregation]
          end

          def parse_flux_result(flux_result)
            result = {}

            flux_result.each do |record|
              sensor =
                find_sensor_by_measurement_and_field(
                  record['_measurement'],
                  record['_field'],
                )
              next unless sensor

              result[sensor] = record['_value']
            end

            result
          end
        end
      end
    end
  end
end
