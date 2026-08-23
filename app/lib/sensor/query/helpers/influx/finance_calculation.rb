module Sensor
  module Query
    module Helpers
      module Influx
        # FinanceBase sensors (grid_costs, savings, ...) carry no calculate
        # block: they turn power into money using the prices valid for the
        # timeframe, so the generic Ruby calculation in Sensor::Query::Base
        # skips them.
        #
        # Both the hourly totals and the chart series need those values per data
        # point, so the calculation lives here -- included by the queries rather
        # than re-implemented by every finance chart.
        module FinanceCalculation
          protected

          # FinanceBase sensors need a Ruby calculation even though they have no
          # calculate block.
          def should_calculate_sensor?(sensor_name)
            super || finance_sensor?(Sensor::Registry[sensor_name])
          end

          # Only sensors without a calculate block need the price-based
          # calculation; total_costs is a FinanceBase sensor that carries one
          # and is summed from its dependencies like any other -- base fee
          # included, because grid_costs, which it sums, already contains it.
          def calculated_value(sensor, dependency_values, sensor_names_with_data)
            return super if sensor.calculated?

            value = sensor.calculate_with_prices(**dependency_values, prices:)
            sensor.with_base_fee(value, base_fee)
          end

          private

          # The base fee that belongs to a single data point. Read from the
          # declarations alone, like #prices: a query whose sensors carry no
          # fee - a feed-in chart, say - never touches the price table for it.
          def base_fee
            @base_fee ||=
              finance_sensors.any?(&:carries_base_fee?) ? base_fee_for(timeframe) : 0
          end

          # The fee in the unit of the values the query hands to the sensors.
          # This one integrates power into energy for the whole timeframe, so
          # the fee is the amount for that timeframe; Series works on power and
          # overrides with a rate.
          def base_fee_for(timeframe)
            BaseFee.for(timeframe)
          end

          # Loaded once per query, and only the price types the involved sensors
          # actually declare: a pure grid_costs query has no business reading the
          # feed-in price.
          def prices
            @prices ||=
              finance_sensors
                .flat_map(&:required_prices)
                .uniq
                .index_with { |name| Price.at(name:, date: timeframe.date) }
          end

          def finance_sensors
            required_sensor_names.filter_map do |name|
              sensor = Sensor::Registry[name]
              sensor if finance_sensor?(sensor)
            end
          end

          def finance_sensor?(sensor)
            sensor.is_a?(Sensor::Definitions::FinanceBase)
          end
        end
      end
    end
  end
end
