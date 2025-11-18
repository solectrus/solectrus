module Sensor
  module Query
    module Helpers
      module Sql
        # Builds SQL SELECT clauses for sensor queries
        class SelectBuilder
          def initialize(sensor_requests:, group_by: nil)
            @sensor_requests = sensor_requests
            @group_by = group_by
          end

          attr_reader :sensor_requests, :group_by

          def build_final_select
            columns = []

            # Add grouping column for time series
            columns << group_by_column_expression if group_by

            columns.concat(build_sensor_columns)

            parts = build_query_parts(columns)
            parts.join("\n\n")
          end

          private

          def build_sensor_columns
            sensor_requests.filter_map do |sensor_name, meta_agg, base_agg|
              sensor = Sensor::Registry[sensor_name]
              final_column = "#{sensor_name}_#{meta_agg}_#{base_agg}"

              # Skip calculated sensors that don't have their own database field
              next if sensor.calculated? && sensor.summary_aggregations.empty?

              if sensor.sql_calculated?
                # Finance sensors use their SQL calculation directly
                calculation =
                  adapt_sql_calculation_for_final(sensor, meta_agg, base_agg)
                "#{calculation} AS #{final_column}"
              else
                # Standard sensors use meta-aggregation on base columns
                base_column = "#{sensor_name}_#{base_agg}"
                "#{meta_agg.upcase}(#{base_column}) AS #{final_column}"
              end
            end
          end

          def adapt_sql_calculation_for_final(sensor, meta_agg, _base_agg)
            # Finance sensors use SQL calculations with price joins
            # Example: SUM(grid_export_power_sum * pf_eur_per_kwh / 1000.0)
            base_calculation = sensor.sql_calculation

            # Finance sensors ALWAYS need meta-aggregation because:
            # 1. For single values: aggregate across all days
            # 2. For time series: aggregate daily calculations within each time period
            # The daily CTE contains per-day calculations that need to be summed/averaged/etc
            "#{meta_agg.upcase}(#{base_calculation})"
          end

          def build_query_parts(columns)
            select_clause = "SELECT\n  #{columns.join(",\n  ")}"
            from_clause = 'FROM daily'
            parts = [select_clause, from_clause]

            if group_by
              parts << 'GROUP BY 1'
              parts << 'ORDER BY 1'
            end

            parts
          end

          GROUP_BY_HASH = {
            day: 'date',
            month: "date_trunc('month', date)::date AS month",
            week: "date_trunc('week', date)::date AS week",
            year: "date_trunc('year', date)::date AS year",
          }.freeze
          private_constant :GROUP_BY_HASH

          def group_by_column_expression
            GROUP_BY_HASH[group_by]
          end
        end
      end
    end
  end
end
