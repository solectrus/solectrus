# Tracks how stale the "latest" values from InfluxDB are at the moment they
# are fetched. The age of a value is a proxy for the real time between data
# points: if we poll faster than data arrives, the age bounces between 0 and
# the true interval. A high percentile of recent ages therefore approximates
# the actual update rate of the data source.
#
# A ring buffer of the last ~20 deltas is kept in the cache. As new samples
# arrive, old ones are pushed out, so a sender that becomes faster or slower
# is picked up after roughly a full buffer of new samples.
class Influx::PollInterval
  # Lower/upper bounds for the derived polling interval.
  MIN_INTERVAL = 5.seconds
  MAX_INTERVAL = 60.seconds

  # Number of recent deltas kept in the ring buffer.
  BUFFER_SIZE = 20

  CACHE_KEY = 'influx:poll_interval:deltas'.freeze

  # Long enough that the last known interval survives idle periods (e.g.
  # overnight), so we don't fall back to MIN_INTERVAL after every pause.
  CACHE_TTL = 30.days

  # Percentile over the recent deltas. P90 tolerates occasional outliers
  # (a single 60s hiccup among 5s data won't double the interval) while still
  # reflecting the slower end of the observed distribution.
  PERCENTILE = 90

  # Small headroom on top of the measured P90: polling exactly at the data
  # rate would often return the previous value again due to jitter.
  SAFETY_FACTOR = 1.2

  public_constant :MIN_INTERVAL, :MAX_INTERVAL
  private_constant :BUFFER_SIZE, :CACHE_KEY, :CACHE_TTL, :PERCENTILE, :SAFETY_FACTOR

  class << self
    def record(latest_time)
      return unless latest_time

      delta = Time.current - latest_time
      return if delta.negative?

      old_deltas = load_deltas
      new_deltas = (old_deltas + [delta.to_f]).last(BUFFER_SIZE)
      Rails.cache.write(CACHE_KEY, new_deltas, expires_in: CACHE_TTL)

      previous_interval = interval_for(old_deltas)
      new_interval = interval_for(new_deltas)
      return if new_interval == previous_interval

      Rails.logger.info(
        '[Influx::PollInterval] interval changed: ' \
          "#{previous_interval.to_i}s -> #{new_interval.to_i}s " \
          "(delta=#{delta.round(2)}s samples=#{new_deltas.size})",
      )
    end

    def current
      interval_for(load_deltas)
    end

    def reset!
      Rails.cache.delete(CACHE_KEY)
    end

    private

    def interval_for(deltas)
      return MIN_INTERVAL if deltas.size < 3

      seconds = (percentile(deltas, PERCENTILE) * SAFETY_FACTOR).round
      seconds.clamp(MIN_INTERVAL.to_i, MAX_INTERVAL.to_i).seconds
    end

    def load_deltas
      Rails.cache.read(CACHE_KEY) || []
    end

    # Nearest-rank percentile: fine for a buffer of ~20 values.
    def percentile(values, pct)
      sorted = values.sort
      index = ((pct / 100.0) * (sorted.size - 1)).round
      sorted[index]
    end
  end
end
