module Sensor
  module Chart
    module Concerns
      # Fills nil gaps in a stacked-area dataset so Chart.js' fill: '-1' has a
      # numeric value at every index. Short outages are bridged with the last
      # known value; gaps longer than the threshold (and leading nils) drop to 0
      # so a brief sensor dropout doesn't read as a real drop to zero.
      module GapBridging
        extend ActiveSupport::Concern

        GAP_BRIDGE_DURATION = 5.minutes
        public_constant :GAP_BRIDGE_DURATION

        def bridge_short_outages!(data, threshold = gap_bridge_buckets)
          last_value = nil
          i = 0
          while i < data.size
            if data[i].nil?
              gap_end = i
              gap_end += 1 while gap_end < data.size && data[gap_end].nil?
              fill = last_value && (gap_end - i) <= threshold ? last_value : 0
              data.fill(fill, i, gap_end - i)
              i = gap_end
            else
              last_value = data[i]
              i += 1
            end
          end
        end

        def gap_bridge_buckets
          GAP_BRIDGE_DURATION.to_i / bucket_interval_seconds
        end

        def bucket_interval_seconds
          (interval || (timeframe.p1h? || timeframe.now? ? 30.seconds : 5.minutes)).to_i
        end
      end
    end
  end
end
