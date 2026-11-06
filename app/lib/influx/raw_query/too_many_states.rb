class Influx
  class RawQuery
    # String fields with more values than Influx::RawQuery#changes numbers.
    # So many values are no states, and the comparisons would cost every
    # sample a long chain.
    class TooManyStates < StandardError
      attr_reader :fields

      def initialize(fields)
        @fields = fields
        super("Too many values in #{fields.join(', ')}")
      end
    end
  end
end
