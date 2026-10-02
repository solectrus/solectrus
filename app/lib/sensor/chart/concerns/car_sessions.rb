module Sensor
  module Chart
    module Concerns
      # The charging sessions of the selected cars, grouped by the columns of
      # a chart. A session belongs to the local date of its start, so it
      # cannot be split across the columns of an hour. Now, the hours view
      # and a day therefore show the wallbox alone.
      module CarSessions
        extend ActiveSupport::Concern
        include CarBuckets
        include SelectedCars

        private

        # Columns of sessions from a day up. Shorter timeframes keep the chart
        # of the class.
        def build_data
          return super if timeframe.short?
          return if buckets.empty?

          { labels:, datasets: session_datasets }
        end

        def labels
          buckets.map { timestamp_to_ms(it.begin) }
        end

        # The sessions of each column, in the order of the columns
        def sessions_by_bucket
          @sessions_by_bucket ||=
            begin
              grouped =
                ChargingSession
                  .of_cars(cars)
                  .in_range(timeframe.beginning, timeframe.ending)
                  .group_by { bucket_start(it.date) }

              buckets.map { grouped.fetch(it.begin, []) }
            end
        end

        def splits
          @splits ||= sessions_by_bucket.map { Car::ChargeSplit.new(it) }
        end

        # Each session splits only with the power splitter
        def split?
          ApplicationPolicy.power_splitter? && splits.all?(&:split?)
        end

        # Nil for an empty column, so it has no bar
        def presence(value)
          value if value&.positive?
        end
      end
    end
  end
end
