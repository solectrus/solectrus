module Sensor
  module Chart
    module Concerns
      # The columns of a car chart: the days of the timeframe, grouped like the
      # SQL charts group them. The rates of each day come from the window
      # around it (see Car::DailyRates).
      module CarBuckets
        extend ActiveSupport::Concern

        private

        def buckets
          @buckets ||=
            (timeframe.effective_beginning_date..timeframe.effective_ending_date)
              .group_by { bucket_start(it) }
              .values
              .map { it.first..it.last }
        end

        def bucket_start(date)
          case sql_grouping_period
          when :year then date.beginning_of_year
          when :month then date.beginning_of_month
          else date
          end
        end
      end
    end
  end
end
