module UpdateCheck::Refresh
  # How long to keep serving the last known-good status when the
  # update server is unreachable.
  STALE_GRACE_PERIOD = 24.hours
  private_constant :STALE_GRACE_PERIOD

  # Minimum time between retry attempts while in the stale phase.
  # Avoids hammering the server (and racking up timeouts on every
  # web request) during a longer outage.
  RETRY_THROTTLE = 15.minutes
  private_constant :RETRY_THROTTLE

  UNKNOWN = { registration_status: 'unknown' }.freeze
  private_constant :UNKNOWN

  private

  def fetch_and_cache_data_safely
    entry = cached_entry
    return resolve_entry(entry) if fresh?(entry)

    # Skip HTTP requests in local environments (development + test).
    # The test suite seeds the cache via spec/support/update_check.rb.
    # Return sensible defaults so components render correctly.
    return fallback_data if self.class.skip_http?

    @mutex.synchronize do
      # Re-read inside the lock: another thread may have just refreshed.
      entry = cached_entry
      return resolve_entry(entry) if fresh?(entry)

      refresh_or_fallback(entry)
    end
  end

  # Returns the entry only if it has the expected wrapper shape, so a
  # legacy/corrupted entry triggers a re-fetch instead of crashing.
  def cached_entry
    entry = cache_manager.get
    return unless entry.is_a?(Hash) && entry[:data].is_a?(Hash)
    return unless entry[:fresh_until].acts_like?(:time)

    entry
  end

  def fresh?(entry)
    entry && Time.current < entry[:fresh_until]
  end

  # Cache is either stale (within grace period) or completely gone.
  # In both cases we try to refresh, but the fallback behavior differs.
  def refresh_or_fallback(entry)
    return entry ? resolve_entry(entry) : UNKNOWN if cache_manager.retry_throttled?

    result = @http_client.fetch_update_data
    result[:status] == :ok ? store_success(result) : handle_failure(result, entry)
  end

  def store_success(result)
    data = result[:data]
    fresh_until = Time.current + result[:expires_in]

    UpdateCheck::NotificationImporter.new(data.delete(:notifications)).call
    cache_manager.set(data, fresh_until:, stale_until: fresh_until + STALE_GRACE_PERIOD)

    @last_verified_signature = data[:signature]
    @verified_result = verified_data(data)
  end

  def handle_failure(result, entry)
    cache_manager.throttle_retry!(RETRY_THROTTLE)
    message = result[:error_message]

    if entry
      # Stale phase: keep serving the last known-good status.
      Rails.logger.warn("UpdateCheck failed (using cached status): #{message}")
      resolve_entry(entry)
    else
      # No cache to fall back on - this becomes visible as "unknown".
      Rails.logger.error("UpdateCheck failed: #{message}")
      reset_verified_cache!
      UNKNOWN
    end
  end

  def resolve_entry(entry)
    data = entry[:data]
    # fallback_data has no signature, skip verification
    self.class.skip_http? ? data : resolve_cached(data)
  end
end
