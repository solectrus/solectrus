class UpdateCheck::CacheManager
  LOCAL_CACHE_DURATION = 5.minutes
  private_constant :LOCAL_CACHE_DURATION

  def initialize
    @local_cache = Concurrent::Map.new
    @mutex = Mutex.new
  end

  # Returns the wrapped entry { data:, fresh_until:, stale_until: } or nil.
  def get
    local_cache || @mutex.synchronize { rails_cache }
  end

  def set(data, fresh_until:, stale_until:)
    entry = { data:, fresh_until:, stale_until: }
    @mutex.synchronize do
      memoize_local(entry)
      Rails.cache.write(cache_key, entry, expires_in: (stale_until - Time.current).seconds)
    end
  end

  def delete
    @mutex.synchronize do
      Rails.cache.delete(cache_key)
      @local_cache.delete(cache_key)
    end
  end

  # Retry throttle: blocks new fetch attempts for a short period
  # after a failure during the stale phase.
  def throttle_retry!(duration)
    Rails.cache.write(retry_throttle_key, true, expires_in: duration)
  end

  def retry_throttled?
    Rails.cache.read(retry_throttle_key) || false
  end

  def clear_retry_throttle
    Rails.cache.delete(retry_throttle_key)
  end

  # Skip cache methods - simple boolean status with automatic expiration
  def skipped_prompt?
    Rails.cache.read(skip_cache_key) || false
  end

  def skip_prompt!(skip_prompt_duration)
    Rails.cache.write(skip_cache_key, true, expires_in: skip_prompt_duration)
  end

  def cached_local?
    local_cache.present?
  end

  def cached_rails?
    Rails.cache.exist?(cache_key)
  end

  def cached?
    cached_local? || cached_rails?
  end

  def cache_key
    "UpdateCheck:#{Rails.configuration.x.git.commit_version}"
  end

  def skip_cache_key
    "UpdateCheck:Skip:#{Rails.configuration.x.git.commit_version}"
  end

  def retry_throttle_key
    "UpdateCheck:RetryThrottle:#{Rails.configuration.x.git.commit_version}"
  end

  private

  def local_cache
    cache = @local_cache[cache_key]
    cache[:entry] if cache && Time.current < cache[:expires_at]
  end

  def memoize_local(entry)
    @local_cache[cache_key] = { entry:, expires_at: Time.current + LOCAL_CACHE_DURATION }
  end

  def rails_cache
    entry = Rails.cache.read(cache_key)
    memoize_local(entry) if entry
    entry
  end
end
