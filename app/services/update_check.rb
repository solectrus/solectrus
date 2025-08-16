class UpdateCheck
  include Singleton

  def initialize
    @cache_manager = CacheManager.new
    @http_client = HttpClient.new
    @mutex = Mutex.new
  end

  class << self
    delegate :sponsoring?,
             :eligible_for_free?,
             :prompt?,
             :simple_prompt?,
             :registered?,
             :unregistered?,
             :registration_grace_period_expired?,
             :skipped_prompt?,
             :skip_prompt!,
             :latest_version,
             :registration_status,
             :kwp,
             :clear_cache!,
             to: :instance
  end

  # For testing purposes only
  delegate :cached?, to: :@cache_manager
  delegate :cached_local?, to: :@cache_manager
  delegate :cached_rails?, to: :@cache_manager

  def latest_version
    latest[:version]
  end

  # One of: unregistered, pending, complete, unknown
  def registration_status
    latest[:registration_status]
  end

  def subscription_plan
    latest[:subscription_plan]
  end

  def kwp
    latest[:kwp]
  end

  def sponsoring?
    subscription_plan.present?
  end

  def eligible_for_free?
    registered? && !prompt? && !sponsoring?
  end

  def prompt?
    registered? && latest[:prompt].present?
  end

  def simple_prompt?
    !sponsoring? && !eligible_for_free?
  end

  def registered?
    registration_status == 'complete'
  end

  def unregistered?
    registration_status.in?(%w[unregistered pending])
  end

  def registration_grace_period_expired?
    return false unless unregistered?

    installation_time = Time.zone.at(Setting.setup_id)
    Time.current > installation_time + 2.weeks
  end

  def latest
    fetch_and_cache_data_safely
  end

  def clear_cache!
    @cache_manager.delete
  end

  def skip_prompt!
    @cache_manager.skip_prompt!(skip_prompt_duration)
  end

  delegate :skipped_prompt?, to: :@cache_manager

  private

  def skip_prompt_duration
    current[:skip_prompt_duration] || 24.hours
  end

  def current
    @cache_manager.get || {}
  end

  def fetch_and_cache_data_safely
    # Double-checked locking pattern to avoid multiple HTTP requests
    # First check: quick cache lookup without lock
    cached_data = current
    return cached_data if cached_data.present?

    @mutex.synchronize do
      # Second check: verify cache is still empty after acquiring lock
      # (another thread might have fetched while we were waiting)
      cached_data = current
      return cached_data if cached_data.present?

      # Cache is empty, fetch new data
      fetch_and_cache_data
    end
  end

  def fetch_and_cache_data
    result = @http_client.fetch_update_data
    expires_at = Time.current + result[:expires_in]
    @cache_manager.set(result[:data], expires_at:)
    result[:data]
  end
end
