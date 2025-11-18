module Sensor
  module Forecast
    # Adds boundary values to forecast data for proper chart rendering
    # Supports two strategies:
    # - :zero - adds zero values at boundaries (for power charts)
    # - :edge - adds first/last actual values at boundaries (for temperature charts)
    class BoundaryAdjuster
      BOUNDARY_INTERVAL = 15.minutes
      NON_ZERO_THRESHOLD = 0.01 # Watts - threshold for considering value as "non-zero"

      private_constant :BOUNDARY_INTERVAL, :NON_ZERO_THRESHOLD

      # Mutates the series raw_data to add boundary zeros (power charts)
      def self.add_zero_boundaries!(series_raw_data)
        new(series_raw_data, strategy: :zero).call
      end

      # Mutates the series raw_data to add boundary edge values (temperature charts)
      # Skips adding boundaries in the past to prevent overlap with actual data
      def self.add_edge_boundaries!(series_raw_data)
        new(series_raw_data, strategy: :edge).call
      end

      def initialize(series_raw_data, strategy:)
        @series_raw_data = series_raw_data
        @strategy = strategy
      end

      attr_reader :series_raw_data, :strategy

      def call
        series_raw_data.each_value do |data|
          next if data.empty?

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
        sorted_entries = extract_relevant_entries(day_entries)
        return if sorted_entries.empty?

        first_entry = sorted_entries.first
        last_entry = sorted_entries.last

        # For edge strategy (temperature): skip boundary before first entry if in the past
        # This prevents forecast data from overlapping with actual data
        if strategy == :edge &&
             first_entry.first - BOUNDARY_INTERVAL <= Time.current
          # Skip adding boundary in the past
        else
          data[first_entry.first - BOUNDARY_INTERVAL] ||= boundary_value(
            first_entry,
          )
        end

        # Always add boundary after last entry
        data[last_entry.first + BOUNDARY_INTERVAL] ||= boundary_value(
          last_entry,
        )
      end

      def extract_relevant_entries(day_entries)
        if strategy == :zero
          # For power: only consider non-zero timestamps
          day_entries
            .filter_map do |timestamp, value|
              [timestamp, value] if non_zero?(value)
            end
            .sort_by(&:first)
        else
          # For temperature: use all entries
          day_entries.sort_by(&:first)
        end
      end

      def boundary_value(entry)
        if strategy == :zero
          0.0
        else
          entry.last # Use the actual value
        end
      end

      def non_zero?(value)
        value&.abs&.>(NON_ZERO_THRESHOLD)
      end
    end
  end
end
