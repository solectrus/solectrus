module Sensor
  module Query
    module Helpers
      module Sql
        # SQL-based query for historical sensor data from summary_values table
        # Supports DSL configuration with meta-aggregations and dependency resolution
        #
        # Usage:
        #   # Simple single value for today
        #   query = Sensor::Query::Helpers::Sql::Total.new(Timeframe.day) do |q|
        #     q.sum :house_power
        #   end
        #   data = query.call
        #   data.house_power  # => 15000.0
        #
        #   # Multiple sensors with different aggregations
        #   query = Sensor::Query::Helpers::Sql::Total.new(Timeframe.new('2025-01')) do |q|
        #     q.sum :house_power, :sum
        #     q.avg :case_temp, :min
        #   end
        #   data = query.call
        #   data.house_power  # => 45000.0
        #   data.case_temp    # => 18.5
        #
        #   # Time series (grouped by period)
        #   query = Sensor::Query::Helpers::Sql::Total.new(Timeframe.new('2025')) do |q|
        #     q.sum :house_power
        #     q.group_by :month
        #   end
        #   data = query.call
        #   data.house_power  # => {Date(2025,1,1) => 3750.0, Date(2025,2,1) => 3400.0, ...}
        class Total < Query::Base
          def initialize(timeframe, &block)
            unless block
              raise ArgumentError, 'Block required for DSL configuration'
            end

            # Build DSL configuration using helper
            dsl_config = build_dsl_configuration(&block)

            # Initialize parent with extracted sensor names
            sensor_names = dsl_config[:requests].map(&:first)
            super(sensor_names, timeframe)

            # Store configuration
            @original_sensor_requests = dsl_config[:requests]
            @timeframe = timeframe
            @group_by = dsl_config[:group_by]

            # Resolve dependencies and prepare final sensor requests
            @sensor_requests = resolve_dependencies
          end

          attr_reader :sensor_requests, :group_by

          private

          # Build DSL configuration from block
          def build_dsl_configuration(&)
            builder = DslBuilder.new
            yield(builder)

            {
              requests: builder.sensor_requests,
              group_by: builder.group_by_value,
            }
          end

          # Resolve all sensor dependencies and build final request list
          def resolve_dependencies
            finance_dependencies = find_finance_dependencies

            required_sensor_names
              .filter_map do |name|
                build_request_for_sensor(name, finance_dependencies)
              end
              .flatten(1)
          end

          # Find dependencies from finance sensors and sensors with SQL calculations
          def find_finance_dependencies
            @original_sensor_requests.each_with_object(
              Set.new,
            ) do |(sensor_name, _, _), dependencies|
              sensor = Sensor::Registry[sensor_name]
              # Include dependencies from:
              # 1. SQL-calculated sensors (FinanceBase)
              # 2. Calculated sensors with sql_calculation method (like savings, solar_price)
              if sensor.sql_calculated? ||
                   (sensor.calculated? && sensor.respond_to?(:sql_calculation))
                dependencies.merge(sensor.dependencies(context: :sql))
              end
            end
          end

          # Build sensor request for a specific sensor
          def build_request_for_sensor(sensor_name, finance_dependencies)
            sensor = Sensor::Registry[sensor_name]

            return if skip_sensor?(sensor, sensor_name, finance_dependencies)
            return unless sensor_available?(sensor_name)

            # Return explicit user request if exists, otherwise create default
            find_existing_request(sensor_name) ||
              create_default_request(sensor_name, sensor)
          end

          # Determine if sensor should be skipped
          def skip_sensor?(sensor, sensor_name, finance_dependencies)
            # Skip calculated sensors that aren't stored in summary (except finance)
            return true if calculated_but_not_stored?(sensor)

            # Skip finance dependencies unless explicitly requested
            finance_dependency_not_requested?(sensor_name, finance_dependencies)
          end

          # Check if sensor is calculated but not stored in summary
          def calculated_but_not_stored?(sensor)
            sensor.calculated? && !sensor.store_in_summary?
          end

          # Check if finance dependency wasn't explicitly requested
          def finance_dependency_not_requested?(
            sensor_name,
            finance_dependencies
          )
            return false if finance_dependencies.exclude?(sensor_name)
            return false if explicitly_requested?(sensor_name)

            # Skip only if ALL requesting sensors are pure SQL-calculated (no Ruby calculate block)
            all_requesting_sensors_are_pure_sql?(sensor_name)
          end

          def explicitly_requested?(sensor_name)
            @original_sensor_requests.any? { |req| req.first == sensor_name }
          end

          def all_requesting_sensors_are_pure_sql?(sensor_name)
            requesting_sensors = find_requesting_sensors(sensor_name)

            # A sensor needs its dependencies loaded if it has a calculate block
            # Pure SQL sensors (FinanceBase without calculate) don't need dependencies loaded
            requesting_sensors.all? { |s| s.sql_calculated? && !s.calculated? }
          end

          def find_requesting_sensors(sensor_name)
            sensors =
              @original_sensor_requests.map do |req|
                Sensor::Registry[req.first]
              end
            sensors.select! { |s| s.dependencies(context: :sql).include?(sensor_name) }
            sensors
          end

          # Find existing request for sensor
          def find_existing_request(sensor_name)
            @original_sensor_requests
              .select { |req| req.first == sensor_name }
              .presence
          end

          # Create default request for sensor
          def create_default_request(sensor_name, sensor)
            # Use allowed_aggregations since SQL queries can handle any allowed aggregation
            first_agg = sensor.allowed_aggregations.first

            first_agg ? [[sensor_name, first_agg, first_agg]] : []
          end

          # Execute SQL query and return formatted results
          def fetch_raw_data
            sql_query = build_sql_query
            raw_result = ActiveRecord::Base.connection.execute(sql_query)
            format_query_result(raw_result)
          end

          # Build SQL query using helper
          def build_sql_query
            QueryBuilder.new(sensor_requests:, timeframe:, group_by:).call
          end

          # Format raw SQL result into structured data
          def format_query_result(raw_result)
            # Handle unexpected result types (should normally be array/enumerable for SELECT)
            return {} unless raw_result.respond_to?(:each)

            mapper = ResultMapper.new(sensor_requests, group_by:, timeframe:)

            # Use appropriate data based on grouping
            data = group_by ? raw_result : raw_result.first
            mapper.call(data)
          end

          def create_data_instance(raw_data, timeframe)
            data_class = group_by ? Sensor::Data::Series : Sensor::Data::Single

            data_class.new(raw_data, timeframe:)
          end

          def query_type
            :sql
          end
        end
      end
    end
  end
end
