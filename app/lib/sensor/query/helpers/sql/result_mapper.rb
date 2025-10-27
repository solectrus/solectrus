module Sensor
  module Query
    module Helpers
      module Sql
        # Maps SQL results to Sensor::Data format. Auto-detects single values vs time series.
        #
        # Usage:
        #   # Single value: mapper.call({"house_power_sum_sum" => 2500}) => {[:house_power, :sum, :sum] => 2500}
        #   # Time series: mapper.call([{"date" => date, "house_power_sum_sum" => 2500}]) => {[:house_power, :sum, :sum] => {date => 2500}}
        #   # With period filling for missing dates when timeframe provided
        class ResultMapper
          def initialize(sensor_requests, group_by: nil, timeframe: nil)
            @sensor_requests = sensor_requests
            @group_by = group_by
            @timeframe = timeframe
          end

          attr_accessor :sensor_requests, :group_by, :timeframe

          # Maps SQL result data to structured sensor data
          #
          # Automatically detects single row vs multiple rows and transforms accordingly:
          #
          # Single row input:  {"house_power_sum_sum" => 2500.0}
          # Single row output: {[:house_power, :sum, :sum] => 2500.0}
          #
          # Multiple rows input:  [{"date" => "2025-01-01", "house_power_sum_sum" => 2500.0}, ...]
          # Multiple rows output: {[:house_power, :sum, :sum] => {Date(2025-01-01) => 2500.0, ...}}
          #
          def call(data)
            validate_data_format!(data)

            if data.respond_to?(:each) && !data.is_a?(Hash)
              # Multiple rows = time series data (Array, PG::Result, etc.)
              map_series_result(data)
            else
              # Single row = single value data
              map_single_result(data)
            end
          end

          private

          # Maps a single SQL result row to a hash for Sensor::Data::Single
          def map_single_result(row)
            return {} if row.nil?
            return {} unless row.respond_to?(:[]) # Handle non-hash-like objects

            transform_sensor_data do |key, column_name|
              [key, row[column_name]]
            end.to_h
          end

          # Maps multiple SQL result rows to a hash for Sensor::Data::Series
          def map_series_result(rows)
            result = initialize_series_result_structure
            populate_series_data(result, rows)

            # Fill complete periods if timeframe is available
            timeframe ? fill_complete_periods(result) : result
          end

          def validate_data_format!(data)
            is_enumerable = data.respond_to?(:each) && !data.is_a?(Hash)

            if group_by.nil?
              # Single value mode: data should be a Hash-like object
              if is_enumerable
                raise ArgumentError,
                      'Expected single row (Hash) for ungrouped query, got enumerable data. ' \
                        'Use group_by parameter for time series data.'
              end
            else
              # Time series mode: data should be enumerable (Array, PG::Result, etc.)
              unless is_enumerable
                raise ArgumentError,
                      "Expected multiple rows (enumerable) for grouped query (group_by: #{group_by.inspect}), got #{data.class}. " \
                        'Remove group_by parameter for single value queries.'
              end
            end
          end

          def initialize_series_result_structure
            sensor_requests.each_with_object(
              {},
            ) do |(sensor_name, meta_agg, base_agg), hash|
              sensor = Sensor::Registry[sensor_name]
              next if sensor.calculated? && sensor.summary_aggregations.empty?

              key = [sensor_name, meta_agg, base_agg]
              hash[key] = {}
            end
          end

          def populate_series_data(result, rows)
            rows.each do |row|
              date = parse_date_from_row(row)
              populate_row_data(result, row, date)
            end
          end

          def populate_row_data(result, row, date)
            return unless row.respond_to?(:[]) # Skip non-hash-like rows

            transform_sensor_data do |key, column_name|
              result[key][date] = row[column_name]
              nil # Don't collect return values
            end
          end

          DATE_HASH = {
            day: 'date',
            month: 'month',
            week: 'week',
            year: 'year',
          }.freeze
          private_constant :DATE_HASH

          def parse_date_from_row(row)
            # Extract date from grouped result
            date_column = DATE_HASH[group_by]

            Date.parse(row[date_column].to_s)
          end

          # Shared transformation logic for both single and series results
          # Yields sensor key and column name for each valid sensor spec
          def transform_sensor_data
            sensor_requests.filter_map do |(sensor_name, meta_agg, base_agg)|
              sensor = Sensor::Registry[sensor_name]

              # Skip calculated sensors that don't have their own database field
              next if sensor.calculated? && sensor.summary_aggregations.empty?

              key = [sensor_name, meta_agg, base_agg]
              column_name = "#{sensor_name}_#{meta_agg}_#{base_agg}"

              yield(key, column_name)
            end
          end

          # Fills complete periods for time series data to ensure no gaps
          def fill_complete_periods(series_data)
            complete_dates = generate_complete_date_range
            return series_data if complete_dates.empty?

            series_data.each_value do |time_series|
              complete_dates.each { |date| time_series[date] ||= nil }
            end

            series_data
          end

          def generate_complete_date_range
            return [] unless group_by && timeframe

            start_date = timeframe.beginning.to_date
            end_date = calculate_completion_end_date

            case group_by
            when :day
              (start_date..end_date).to_a
            when :month
              (start_date.beginning_of_month..end_date.beginning_of_month).step(
                1.month,
              ).to_a
            when :year
              [start_date.beginning_of_year]
            else
              []
            end
          end

          def calculate_completion_end_date
            return timeframe.ending.to_date if timeframe.relative?
            return calculate_day_completion_end if group_by == :day
            return calculate_month_completion_end if group_by == :month

            timeframe.ending.to_date
          end

          def calculate_day_completion_end
            date = timeframe.date
            return date.end_of_week.to_date if timeframe.week?
            return date.end_of_month.to_date if timeframe.month?
            return date.end_of_year.to_date if timeframe.year?

            timeframe.ending.to_date
          end

          def calculate_month_completion_end
            if timeframe.year?
              timeframe.date.end_of_year.to_date
            else
              timeframe.ending.to_date
            end
          end
        end
      end
    end
  end
end
