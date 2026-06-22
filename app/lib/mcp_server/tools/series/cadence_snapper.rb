module McpServer
  module Tools
    class Series < Base
      # Decides whether a series request should be re-queried at a coarser
      # resolution because the chosen bucket is finer than the data's own
      # sample cadence - which would otherwise return a mostly-null grid (e.g.
      # 1m buckets on a 15-min forecast sensor).
      module CadenceSnapper
        module_function

        # Returns the [seconds, label] to re-query at, or nil to keep the
        # current resolution.
        #
        # The densest sensor decides, so a dense sensor in the request keeps
        # the fine grid. Snapping needs two signals together: the sample
        # cadence is coarser than the bucket AND the grid is actually mostly
        # null. The latter guards against a deliberately sparse window (a few
        # points with a gap), where the lone gap is no reliable cadence.
        #
        # `resolutions` is the ascending [[label, seconds], ...] ladder.
        def snap(series_list, interval, resolutions)
          cadence, null_fraction =
            series_list.filter_map { |series| stats(series) }.min_by { |gap, _fraction| gap }
          return unless snap?(cadence, null_fraction, interval)

          # Finest resolution whose bucket spans the cadence, so each bucket
          # holds roughly one sample. Reverse [label, seconds] to the
          # [seconds, label] callers expect.
          (resolutions.find { |_label, secs| secs >= cadence } || resolutions.last).reverse
        end

        def snap?(cadence, null_fraction, interval)
          cadence && cadence > interval && null_fraction > 0.5
        end

        # [median gap between non-null points (seconds), fraction of null
        # buckets] for one {time => value} series, or nil when fewer than two
        # samples leave the cadence unknowable.
        def stats(series)
          times = (series || {}).compact.keys.sort
          return if times.size < 2

          # Typical sample spacing - median gap, like Sensor::Chart::Base.
          gaps = times.each_cons(2).map { |a, b| (b - a).to_i }
          cadence = gaps.sort[gaps.size / 2]

          [cadence, 1.0 - times.size.fdiv(series.size)]
        end
      end
    end
  end
end
