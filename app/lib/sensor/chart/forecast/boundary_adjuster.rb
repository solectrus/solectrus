module Sensor
  module Chart
    class Forecast < Base
      # Adds boundary zeros to forecast data for proper chart rendering
      class BoundaryAdjuster
        BOUNDARY_INTERVAL = 15.minutes
        NON_ZERO_THRESHOLD = 0.01 # Watts - threshold for considering value as "non-zero"

        private_constant :BOUNDARY_INTERVAL, :NON_ZERO_THRESHOLD

        class << self
          # Mutates the series raw_data to add boundary zeros
          # @param series_raw_data [Hash] The raw data from series
          def add_boundaries!(series_raw_data)
            series_raw_data.each_value do |data|
              group_by_date(data).each_value do |day_entries|
                add_day_boundaries!(day_entries, data)
              end
            end
          end

          private

          def group_by_date(data)
            data.group_by { |timestamp, _| timestamp.to_date }
          end

          def add_day_boundaries!(day_entries, data)
            non_zero_timestamps = extract_non_zero_timestamps(day_entries)
            return if non_zero_timestamps.empty?

            data[non_zero_timestamps.first - BOUNDARY_INTERVAL] ||= 0.0
            data[non_zero_timestamps.last + BOUNDARY_INTERVAL] ||= 0.0
          end

          def extract_non_zero_timestamps(day_entries)
            day_entries
              .filter_map { |timestamp, value| timestamp if non_zero?(value) }
              .sort
          end

          def non_zero?(value)
            value&.abs&.>(NON_ZERO_THRESHOLD)
          end
        end
      end
    end
  end
end
