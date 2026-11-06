class Influx
  class RawQuery
    # The aggregation of a boolean field, see Influx::RawQuery#windows
    module Flags
      # A flag is aggregated from two counts per window, of all its samples and
      # of the true ones. Both run in the storage engine. Converting the flag to
      # 0/1 in Flux first would read every sample into the Flux engine instead:
      # 6.8 s against 70 ms for one flag over 30 days at 10-second samples.
      SAMPLES = 'flag_samples'.freeze
      TRUES = 'flag_trues'.freeze
      STREAMS = [SAMPLES, TRUES].freeze
      FUNCTIONS = {
        max: ->(trues, _samples) { trues.positive? ? 1 : 0 },
        min: ->(trues, samples) { trues == samples ? 1 : 0 },
        mean: ->(trues, samples) { trues.fdiv(samples) },
      }.freeze
      public_constant :SAMPLES, :TRUES, :STREAMS
      private_constant :FUNCTIONS

      private

      # The rows of the flags, shaped like those of the other streams. A window
      # with no true sample has no row in "flag_trues".
      def flags_from(counts, function)
        samples, trues = counts.partition { it['result'] == SAMPLES }
        true_counts = trues.to_h { [window_key(it), it['_value']] }

        samples.map do |row|
          row.merge('_value' => FUNCTIONS[function].call(true_counts.fetch(window_key(row), 0), row['_value']))
        end
      end

      def window_key(row) = row.except('result', 'table', '_value')
    end
  end
end
