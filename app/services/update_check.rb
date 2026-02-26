class UpdateCheck
  include Singleton
  include SignatureCache

  def initialize
    @cache_manager = CacheManager.new
    @http_client = HttpClient.new
    @mutex = Mutex.new
  end

  attr_reader :cache_manager

  class << self
    delegate :sponsoring?,
             :eligible_for_free?,
             :prompt?,
             :action_required?,
             :registered?,
             :unregistered?,
             :registration_grace_period_expired?,
             :free_trial?,
             :free_trial_ends_at,
             :skipped_prompt?,
             :skip_prompt!,
             :latest_version,
             :registration_status,
             :kwp,
             :clear_cache!,
             to: :instance
  end

  def self.skip_http?
    Rails.env.local?
  end

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

  def free_trial_ends_at
    value = latest[:free_trial_ends_at]
    Time.zone.parse(value) if value.present?
  end

  def free_trial?
    free_trial_ends_at.present? && free_trial_ends_at >= Time.current
  end

  def eligible_for_free?
    latest[:eligible_for_free].present?
  end

  def prompt?
    registered? && latest[:prompt].present?
  end

  def action_required?
    !sponsoring? && (!registered? || prompt?)
  end

  def registered?
    registration_status == 'complete'
  end

  def unregistered?
    registration_status.in?(%w[unregistered pending])
  end

  def registration_grace_period_expired?
    return false if self.class.skip_http?
    return false unless unregistered?

    setup_id = Setting.setup_id
    if setup_id.nil?
      # Fallback: seed setup_id now if missing
      Setting.seed!
      setup_id = Setting.setup_id

      # Give up if still nil
      return false if setup_id.nil?
    end

    installation_time = Time.zone.at(setup_id)
    Time.current > installation_time + 2.weeks
  end

  def latest
    fetch_and_cache_data_safely
  end

  def clear_cache!
    reset_verified_cache!
    cache_manager.delete
    # Also clear sensor cache since permissions may have changed
    Sensor::Config.clear_cache!
  end

  def skip_prompt!
    cache_manager.skip_prompt!(skip_prompt_duration)
  end

  def fallback_data
    @fallback_data ||= {
      version: Rails.configuration.x.git.commit_version,
      registration_status: 'complete',
      eligible_for_free: true,
    }.freeze
  end

  delegate :skipped_prompt?, to: :cache_manager

  private

  def skip_prompt_duration
    current[:skip_prompt_duration] || 24.hours
  end

  def current
    cache_manager.get || {}
  end

  def fetch_and_cache_data_safely
    # Double-checked locking pattern to avoid multiple HTTP requests
    # First check: quick cache lookup without lock
    cached_data = current
    if cached_data.present?
      # Development/Test: fallback_data has no signature, skip verification
      return cached_data if self.class.skip_http?

      return resolve_cached(cached_data)
    end

    reset_verified_cache!

    # Skip HTTP requests in local environments (development + test).
    # The test suite seeds the cache via spec/support/update_check.rb.
    # Return sensible defaults so components render correctly.
    return fallback_data if self.class.skip_http?

    @mutex.synchronize do
      # Second check: another thread might have fetched while we were waiting
      cached_data = current
      return resolve_cached(cached_data) if cached_data.present?

      fetch_and_cache_data
    end
  end

  def fetch_and_cache_data
    result = @http_client.fetch_update_data
    expires_at = Time.current + result[:expires_in]

    import_notifications(result[:data].delete(:notifications))
    # Cache includes :signature for verification on subsequent reads
    cache_manager.set(result[:data], expires_at:)

    @last_verified_signature = result[:data][:signature]
    @verified_result = verified_data(result[:data])
  end

  def import_notifications(notifications_data)
    NotificationImporter.new(notifications_data).call
  end
end
