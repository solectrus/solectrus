class UpdateCheck
  include Singleton

  def initialize
    @cache_manager = CacheManager.new
    @http_client = HttpClient.new
  end

  class << self
    delegate :sponsoring?,
             :eligible_for_free?,
             :prompt?,
             :simple_prompt?,
             :unregistered?,
             :skipped_prompt?,
             :skip_prompt!,
             :latest_version,
             :registration_status,
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

  def sponsoring?
    subscription_plan.present?
  end

  def eligible_for_free?
    registration_status == 'complete' && !prompt? && !sponsoring?
  end

  def prompt?
    registration_status == 'complete' && latest[:prompt].present?
  end

  def simple_prompt?
    !sponsoring? && !eligible_for_free?
  end

  def unregistered?
    registration_status.in?(%w[unregistered pending])
  end

  def latest
    current.presence || fetch_and_cache_data
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

  def fetch_and_cache_data
    result = @http_client.fetch_update_data
    expires_at = Time.current + result[:expires_in]
    @cache_manager.set(result[:data], expires_at:)
    result[:data]
  end
end
