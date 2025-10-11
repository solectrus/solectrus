module Sensor
  module Query
    module Helpers
      # Coordinates SQL query building using specialized builder classes
      class SqlQueryBuilder
        def initialize(sensor_requests:, timeframe:, group_by: nil)
          @sensor_requests = sensor_requests
          @timeframe = timeframe
          @group_by = group_by

          analyze_sensor_requirements
        end

        attr_reader :sensor_requests, :timeframe, :group_by

        def call
          [
            cte_builder.build_price_cte,
            cte_builder.build_daily_cte,
            select_builder.build_final_select,
          ].compact.join("\n\n")
        end

        private

        attr_accessor :required_fields,
                      :required_aggregations,
                      :finance_sensors,
                      :standard_sensors,
                      :calculated_sensors,
                      :required_prices

        def cte_builder
          @cte_builder ||=
            SqlCteBuilder.new(
              sensor_requests:,
              timeframe:,
              required_prices:,
              required_fields:,
              required_aggregations:,
            )
        end

        def select_builder
          @select_builder ||= SqlSelectBuilder.new(sensor_requests:, group_by:)
        end

        def analyze_sensor_requirements
          initialize_collections
          sensor_requests.each { |request| categorize_sensor(*request) }
        end

        def initialize_collections
          self.required_fields = Set.new
          self.required_aggregations = Set.new
          self.finance_sensors = []
          self.standard_sensors = []
          self.calculated_sensors = []
          self.required_prices = Set.new
        end

        def categorize_sensor(sensor_name, meta_agg, base_agg)
          sensor = Sensor::Registry[sensor_name]

          if sensor.sql_calculated?
            process_finance_sensor(sensor_name, meta_agg, base_agg, sensor)
          elsif sensor.calculated? && sensor.summary_aggregations.empty?
            calculated_sensors << [sensor_name, meta_agg, base_agg]
          else
            process_standard_sensor(sensor_name, meta_agg, base_agg)
          end
        end

        def process_finance_sensor(sensor_name, meta_agg, base_agg, sensor)
          finance_sensors << [sensor_name, meta_agg, base_agg]
          required_fields.merge(sensor.dependencies)
          required_prices.merge(sensor.required_prices)
          # Finance sensors need sum aggregation for their field calculations
          sensor.dependencies.each { |_field| required_aggregations << :sum }
        end

        def process_standard_sensor(sensor_name, meta_agg, base_agg)
          standard_sensors << [sensor_name, meta_agg, base_agg]
          required_fields << sensor_name
          required_aggregations << base_agg
        end
      end
    end
  end
end
