module Sensor
  module Query
    module Helpers
      module Sql
        # Builds SQL Common Table Expressions (CTEs) for sensor queries
        class CteBuilder
          def initialize(
            sensor_requests:,
            timeframe:,
            required_prices:,
            required_fields:,
            required_aggregations:
          )
            @sensor_requests = sensor_requests
            @timeframe = timeframe
            @required_prices = required_prices
            @required_fields = required_fields
            @required_aggregations = required_aggregations
          end

          attr_reader :sensor_requests,
                      :timeframe,
                      :required_prices,
                      :required_fields,
                      :required_aggregations

          def build_price_cte
            return unless needs_prices?

            price_names = required_prices.map { |p| "'#{p}'" }.join(',')

            <<~SQL.squish
              WITH price_ranges AS (
                SELECT
                  name,
                  starts_at,
                  LEAD(starts_at, 1, 'infinity'::date) OVER (PARTITION BY name ORDER BY starts_at) AS next_start,
                  value::numeric AS eur_per_kwh
                FROM prices
                WHERE name IN (#{price_names})
              ),
            SQL
          end

          def build_daily_cte
            cte_start = needs_prices? ? 'daily AS' : 'WITH daily AS'
            columns = build_daily_columns
            joins = build_join_clauses
            joins_clause = joins.present? ? "\n  #{joins}\n" : nil
            where_clause = build_where_clause

            <<~SQL.squish
              #{cte_start} (
                SELECT
                  #{columns.join(",\n        ")}
                FROM summary_values sv
                #{joins_clause}
                #{where_clause}
                GROUP BY sv.date
              )
            SQL
          end

          private

          def needs_prices?
            required_prices.any?
          end

          def build_daily_columns
            columns = ['sv.date']
            columns.concat(build_sensor_filter_columns)
            columns.concat(build_price_columns) if needs_prices?
            columns
          end

          def build_sensor_filter_columns
            field_agg_combinations = collect_field_aggregation_combinations

            field_agg_combinations.map do |field_name, base_agg|
              column_name = "#{field_name}_#{base_agg}"
              filter_clause =
                "WHERE sv.aggregation = '#{base_agg}' AND sv.field = '#{field_name}'"
              "#{base_agg.upcase}(sv.value) FILTER (#{filter_clause}) AS #{column_name}"
            end
          end

          def collect_field_aggregation_combinations
            combinations = Set.new

            # Use required_fields (which are already resolved to storable fields)
            # combined with required_aggregations
            required_fields.each do |field_name|
              required_aggregations.each do |agg|
                combinations << [field_name, agg]
              end
            end

            combinations
          end

          def build_price_columns
            columns = []
            if required_prices.include?(:electricity)
              columns << 'MAX(pb.eur_per_kwh) AS pb_eur_per_kwh'
            end
            if required_prices.include?(:feed_in)
              columns << 'MAX(pf.eur_per_kwh) AS pf_eur_per_kwh'
            end
            columns
          end

          def build_join_clauses
            return unless needs_prices?

            joins = []

            joins << <<~SQL.squish if required_prices.include?(:electricity)
              JOIN price_ranges pb
                ON pb.name = 'electricity'
               AND sv.date >= pb.starts_at
               AND sv.date < pb.next_start
            SQL

            joins << <<~SQL.squish if required_prices.include?(:feed_in)
              JOIN price_ranges pf
                ON pf.name = 'feed_in'
               AND sv.date >= pf.starts_at
               AND sv.date < pf.next_start
            SQL

            joins.join("\n\n")
          end

          def build_where_clause
            conditions = []

            # Date range condition
            start_date = timeframe.beginning.to_date
            end_date = timeframe.ending.to_date
            conditions << "sv.date BETWEEN DATE '#{start_date}' AND DATE '#{end_date}'"

            # Aggregation filter
            if required_aggregations.any?
              agg_list =
                required_aggregations.map { |agg| "'#{agg}'" }.join(',')
              conditions << "sv.aggregation IN (#{agg_list})"
            end

            # Field filter
            if required_fields.any?
              field_list =
                required_fields.map { |field| "'#{field}'" }.join(',')
              conditions << "sv.field IN (#{field_list})"
            end

            "WHERE #{conditions.join("\n    AND ")}"
          end
        end
      end
    end
  end
end
