module Sensor
  module Chart
    module Concerns
      # A chart of the car page with a column for each day, month or year of
      # the timeframe. The numbers come from the report of the page (see
      # Car::Report), and a column holds the days of its period. A column
      # therefore shows the same number as the tile of that period, and the
      # columns add up to the tile of the timeframe.
      #
      # The numbers come from full days, so the chart draws a day at least.
      module CarColumns
        extend ActiveSupport::Concern

        class_methods do
          def supports?(timeframe)
            !timeframe.short?
          end
        end

        include SelectedCars

        private

        def report
          @report ||= Car::Report.new(timeframe, cars)
        end

        # The dates of each column, grouped like the SQL charts group them.
        # The first column can start after the first day of its month or
        # year, on the installation date.
        def columns
          @columns ||= report.dates.group_by { column_start(it) }.values.map { it.first..it.last }
        end

        def column_start(date)
          case sql_grouping_period
          when :year then date.beginning_of_year
          when :month then date.beginning_of_month
          else date
          end
        end

        def labels
          columns.map { timestamp_to_ms(it.begin) }
        end

        # A column without each day of its calendar period, because the
        # installation date, today or the edge of a range cuts it. The
        # running day counts as well. The rule is the one of the timeframe,
        # so it asks for the calendar period, which the first column can
        # start after.
        def partial?(column)
          timeframe.partial_period?(column_start(column.begin), sql_grouping_period)
        end

        # Nil for an empty column, so it has no bar
        def presence(value)
          value if value&.positive?
        end
      end
    end
  end
end
