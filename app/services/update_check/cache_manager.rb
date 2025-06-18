class UpdateCheck::CacheManager
  LOCAL_CACHE_DURATION = 5.minutes
  private_constant :LOCAL_CACHE_DURATION

  def initialize
    @local_cache = Concurrent::Map.new
    @mutex = Mutex.new
  end

  def get
    local_cache || @mutex.synchronize { rails_cache }
  end

  def set(data, expires_at:)
    update_local_cache(data, expires_in: LOCAL_CACHE_DURATION)
    update_rails_cache(data, expires_at:)
  end

  def delete
    Rails.cache.delete(cache_key)
    @local_cache.delete(cache_key)
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

  private

  def local_cache
    cache = @local_cache[cache_key]
    cache[:data] if cache && Time.current < cache[:expires_at]
  end

  def update_local_cache(data, expires_in:)
    @local_cache[cache_key] = {
      data: data,
      expires_at: Time.current + expires_in,
    }
  end

  def update_rails_cache(data, expires_at:)
    expires_in = (expires_at - Time.current).seconds
    Rails.cache.write(cache_key, data, expires_in: expires_in)
  end

  def rails_cache
    result = Rails.cache.read(cache_key)
    update_local_cache(result, expires_in: LOCAL_CACHE_DURATION) if result
    result
  end
end
