module McpServer
  module Tools
    class Series < Base
      # Maps the client-facing aggregation to the internal query symbol
      # ("mean" is the query layer's :avg). Anything outside this set - notably
      # "sum", which would total a coarse series rather than integrate energy
      # and thus read as a misleading total - is rejected, so a client that
      # ignores the schema enum still gets a clear error instead of bad data.
      # Period totals (Wh/kWh, costs) belong in get_totals.
      module Aggregation
        module_function

        INTERNAL = { 'mean' => :avg, 'min' => :min, 'max' => :max }.freeze
        private_constant :INTERNAL

        def internal(aggregation)
          INTERNAL.fetch(aggregation.to_s) do
            raise ArgumentError,
                  "Unsupported aggregation '#{aggregation}'. Use 'mean', " \
                    "'min' or 'max'. For period totals (Wh/kWh, costs) use " \
                    'get_totals.'
          end
        end
      end
    end
  end
end
