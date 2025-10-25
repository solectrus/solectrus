module Sensor
  module Query
    class Ranking < Base # rubocop:disable Metrics/ClassLength
      def initialize(sensor_name, aggregation: :sum, period: :day, **options)
        @sensor = Sensor::Registry[sensor_name]
        @aggregation = aggregation.to_sym
        @period = period.to_sym
        @desc = options.fetch(:desc, true)
        @limit = options.fetch(:limit, 10)

        validate_aggregation!
        validate_period!

        # Calculate start/stop dates (used directly in SQL queries)
        calculate_date_range(options[:start], options[:stop])
        return unless valid_range

        # Initialize Base (timeframe not used, we query directly with start..stop)
        super([sensor.name], nil)
      end

      attr_reader :sensor,
                  :aggregation,
                  :period,
                  :start,
                  :stop,
                  :desc,
                  :limit,
                  :valid_range

      def call
        return [] unless valid_range

        @call ||=
          if find_sql_dependencies.any?
            fetch_sql_based_ranking_data
          else
            fetch_ranking_data
          end.map { |date, value| { date: date.to_date, value: value.to_f } }
      end

      private

      PERIOD_SQL = {
        week: "DATE_TRUNC('week', date)",
        month: "DATE_TRUNC('month', date)",
        year: "DATE_TRUNC('year', date)",
      }.freeze
      private_constant :PERIOD_SQL

      def fetch_ranking_data
        fields = storable_fields_for(sensor)
        base_scope =
          SummaryValue.where(date: start..stop, field: fields, aggregation:)

        unless desc
          base_scope = base_scope.where(SummaryValue.arel_table[:value].gt(10))
        end

        # First aggregate by date (handles multiple fields)
        daily_scope = aggregate_by_date(base_scope, fields)

        # Then aggregate by period (or use daily data directly)
        if period == :day
          rank_daily(daily_scope, fields)
        else
          aggregate_by_period(daily_scope)
        end
      end

      def aggregate_by_date(scope, fields)
        return scope if fields.size == 1

        # Multiple fields: sum by date
        scope.select('date, SUM(value) as value').group(:date)
      end

      def rank_daily(scope, fields)
        if fields.size > 1
          # Grouped query: use SUM(value)
          scope
            .order(Arel.sql("SUM(value) #{order_direction}"))
            .limit(limit)
            .pluck(:date, Arel.sql('SUM(value)'))
        else
          # Non-grouped query: use value directly
          scope
            .order(Arel.sql("value #{order_direction}"))
            .limit(limit)
            .pluck(:date, :value)
        end
      end

      def aggregate_by_period(daily_scope)
        period_sql = PERIOD_SQL.fetch(period)

        SummaryValue
          .from("(#{daily_scope.to_sql}) AS daily_data")
          .select(
            Arel.sql(
              "#{period_sql.sub('date', 'daily_data.date')} AS period_date",
            ),
            Arel.sql(
              "#{aggregation.to_s.upcase}(daily_data.value) AS agg_value",
            ),
          )
          .group(Arel.sql(period_sql.sub('date', 'daily_data.date')))
          .order(Arel.sql("agg_value #{order_direction}"))
          .limit(limit)
          .map { |r| [r.period_date, r.agg_value] }
      end

      def order_direction
        desc ? 'DESC' : 'ASC'
      end

      # Recursively resolve sensor to fields that are actually stored in summary_values
      def storable_fields_for(sensor, visited = Set.new)
        return [sensor.name] if sensor.store_in_summary?
        return [] if visited.include?(sensor.name)

        sensor
          .dependencies
          .flat_map do |dep|
            storable_fields_for(Sensor::Registry[dep], visited + [sensor.name])
          end
          .uniq
      end

      def calculate_date_range(start_param, stop_param)
        calculated_start = calculate_start(start_param)
        calculated_stop = calculate_stop(stop_param)

        # Check if range is valid (start must be before or equal to stop)
        if calculated_start <= calculated_stop
          @start = calculated_start
          @stop = calculated_stop
          @valid_range = true
        else
          # No complete periods exist - explicitly set nil to indicate invalid state
          @start = nil
          @stop = nil
          @valid_range = false
        end
      end

      def calculate_start(start_param)
        date = start_param || Rails.application.config.x.installation_date
        return date if desc

        # For ascending rankings: always exclude incomplete periods
        beginning = date.public_send("beginning_of_#{period}")

        # If at period boundary and complete period, use it
        # Otherwise skip to next period (incomplete period)
        if date == beginning &&
             date >
               Rails.application.config.x.installation_date.beginning_of_day
          beginning
        else
          beginning + 1.public_send(period)
        end
      end

      def calculate_stop(stop_param)
        date = stop_param || Date.current
        return date if desc

        # For ascending: exclude incomplete period
        ending = date.public_send("end_of_#{period}")

        if date == ending && date < Date.current
          ending
        else
          ending - 1.public_send(period)
        end
      end

      VALID_PERIODS = %i[day week month year].freeze
      private_constant :VALID_PERIODS

      def validate_aggregation!
        return if sensor.allowed_aggregations.include?(aggregation)

        raise ArgumentError,
              "Sensor #{sensor.name} doesn't support #{aggregation} aggregation. " \
                "Available: #{sensor.allowed_aggregations.join(', ')}"
      end

      def validate_period!
        return if VALID_PERIODS.include?(period)

        raise ArgumentError,
              "Invalid period #{period.inspect}. Must be one of: #{VALID_PERIODS.join(', ')}"
      end

      # Unified method for SQL-based ranking (both direct and composite sensors)
      def fetch_sql_based_ranking_data
        sql_deps = find_sql_dependencies
        calculation = build_sql_calculation(sql_deps)
        cte_builder = build_cte(sql_deps)
        price_cte = cte_builder.build_price_cte
        daily_cte = cte_builder.build_daily_cte

        sql =
          if period == :day
            build_daily_ranking_sql(price_cte, daily_cte, calculation)
          else
            build_period_ranking_sql(price_cte, daily_cte, calculation)
          end

        SummaryValue
          .connection
          .execute(sql)
          .map { |row| [row['date'] || row['period_date'], row['value']] }
      end

      # Find SQL-calculated dependencies for current sensor
      def find_sql_dependencies
        return [sensor.name] if sensor.sql_calculated? && !sensor.calculated?

        deps = transitive_sql_dependencies
        # If sensor has sql_calculation but no SQL dependencies, use it directly
        return [sensor.name] if sensor.sql_calculated? && deps.empty?

        deps
      end

      # Get all transitive SQL-calculated dependencies (memoized)
      def transitive_sql_dependencies
        @transitive_sql_dependencies ||=
          begin
            all_deps =
              Sensor::DependencyResolver.new([sensor.name]).resolve -
                [sensor.name]
            all_deps.select { |dep| Sensor::Registry[dep].sql_calculated? }
          end
      end

      # Build SQL calculation expression (direct or composite)
      def build_sql_calculation(sql_deps)
        return sensor.sql_calculation if sensor.respond_to?(:sql_calculation)
        if sql_deps.size == 1
          return Sensor::Registry[sql_deps.first].sql_calculation
        end

        # Composite: combine multiple SQL calculations
        sql_deps
          .map { |dep| "(#{Sensor::Registry[dep].sql_calculation})" }
          .join(' + ')
      end

      # Build CTE with required prices and fields
      def build_cte(sql_deps)
        custom_sql = sensor.respond_to?(:sql_calculation)
        required_prices = Set.new
        required_fields = Set.new

        # Collect prices from sensor itself
        if custom_sql && sensor.respond_to?(:required_prices)
          required_prices.merge(sensor.required_prices)
        end

        # Collect prices and fields from SQL dependencies
        sql_deps.each do |dep_name|
          dep_sensor = Sensor::Registry[dep_name]
          if dep_sensor.respond_to?(:required_prices)
            required_prices.merge(dep_sensor.required_prices)
          end

          fields = storable_fields_for(dep_sensor)
          required_fields.merge(fields)
        end

        # Build sensor requests (only leaf sensors for custom SQL)
        sensor_requests = build_sensor_requests(sql_deps, custom_sql)

        Sensor::Query::Helpers::SqlCteBuilder.new(
          sensor_requests:,
          timeframe:
            Timeframe.new(
              "#{start.strftime('%Y-%m-%d')}..#{stop.strftime('%Y-%m-%d')}",
            ),
          required_prices: required_prices.to_a,
          required_fields: required_fields.to_a,
          required_aggregations: [:sum],
        )
      end

      def build_sensor_requests(sql_deps, custom_sql)
        return sql_deps.map { |dep| [dep, aggregation, :sum] } unless custom_sql

        sql_deps.each_with_object([]) do |dep, arr|
          unless Sensor::Registry[dep].calculated?
            arr << [dep, aggregation, :sum]
          end
        end
      end

      # Build daily ranking SQL
      def build_daily_ranking_sql(price_cte, daily_cte, calculation)
        <<~SQL.squish
          #{price_cte}
          #{daily_cte}
          SELECT date, #{calculation} AS value
          FROM daily
          ORDER BY value #{order_direction}
          LIMIT #{limit}
        SQL
      end

      # Build period-aggregated ranking SQL
      def build_period_ranking_sql(price_cte, daily_cte, calculation)
        period_sql = PERIOD_SQL.fetch(period)

        # For sensors with custom period aggregation (like ratios), use that instead
        aggregation_expr =
          if sensor.respond_to?(:sql_calculation_period)
            sensor.sql_calculation_period
          else
            "#{aggregation.to_s.upcase}(#{calculation})"
          end

        <<~SQL.squish
          #{price_cte}
          #{daily_cte}
          SELECT
            #{period_sql} AS period_date,
            #{aggregation_expr} AS value
          FROM daily
          GROUP BY #{period_sql}
          ORDER BY value #{order_direction}
          LIMIT #{limit}
        SQL
      end
    end
  end
end
