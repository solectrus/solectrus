module Sensor
  module Query
    # Automatic query dispatcher - delegates to optimal backend based on timeframe
    # Provides unified DSL that works for both InfluxDB and SQL backends
    #
    # Usage:
    #   # Hourly timeframe (P1H-P99H) uses Influx::Total
    #   query = Sensor::Query::Total.new(Timeframe.new('P24H')) do |q|
    #     q.sum :house_power
    #     q.sum :grid_costs
    #   end
    #
    #   # Daily/monthly/yearly timeframe uses Sql
    #   query = Sensor::Query::Total.new(Timeframe.day) do |q|
    #     q.sum :house_power
    #     q.sum :grid_costs
    #   end
    #
    #   # Call is identical for both
    #   data = query.call
    #   data.house_power  # => 15000.0
    #   data.grid_costs   # => 4.5
    class Total
      attr_reader :executor

      def initialize(timeframe, &block)
        raise ArgumentError, 'Block required for DSL configuration' unless block

        @executor =
          if timeframe.hours?
            Helpers::Influx::Total.new(timeframe, &block)
          else
            Helpers::Sql::Total.new(timeframe, &block)
          end
      end

      delegate :call, :timeframe, to: :@executor
    end
  end
end
