class UpdateCheck
  include Singleton
  include SignatureCache
  include Refresh
  include Fallback

  def initialize
    @cache_manager = CacheManager.new
    @http_client = HttpClient.new
    @mutex = Mutex.new
  end

  attr_reader :cache_manager

  class << self
    delegate :prompt?,
             :action_required?,
             :registered?,
             :unregistered?,
             :unknown?,
             :registration_grace_period_expired?,
             :registration_reminder_due?,
             :trial_available?,
             :premium_reason,
             :premium_ends_at,
             :skipped_prompt?,
             :skip_prompt!,
             :snoozed_banner?,
             :snooze_banner!,
             :latest_version,
             :registration_status,
             :kwp,
             :clear_cache!,
             to: :instance
  end

  def self.skip_http?
    Rails.env.local?
  end

  def self.profile_code
    ApplicationPolicy.car? ? 1 : 0
  end

  def latest_version
    latest[:version]
  end

  # One of: unregistered, pending, complete, unknown
  def registration_status
    latest[:registration_status]
  end

  def kwp
    latest[:kwp]
  end

  # Why this installation has the full feature set, decided by the update
  # server. Today one of: sponsoring, eligible_for_free, free_trial, intro -
  # or nil. The server can add a name at any time, so nothing here compares
  # against a list (see PremiumStatus).
  #
  # This is the only answer about the feature set. The older single fields are
  # still on the wire for older clients, and this app reads none of them.
  def premium_reason
    latest[:premium_reason].presence&.to_sym
  end

  def premium_ends_at
    time_from(:premium_ends_at)
  end

  def trial_available?
    latest[:trial_available].present?
  end

  def prompt?
    registered? && latest[:prompt].present?
  end

  # Whether to raise the warning icon. Both axes can ask for attention, but the
  # quiet period after the installation does not - nothing is expected yet.
  def action_required?
    registration_reminder_due? || prompt?
  end

  def registered?
    registration_status == 'complete'
  end

  def unregistered?
    registration_status.in?(%w[unregistered pending])
  end

  # Whether the update server answered at all. A failed request leaves no field
  # of an answer behind, only this marker (see Refresh::UNKNOWN), and the
  # server itself never sends it.
  #
  # Nothing is granted then, and nothing is enforced either. Both look like the
  # answer "no", so the difference must be named where it is shown.
  def unknown?
    registration_status == 'unknown'
  end

  # A fresh installation is left alone for a few days. After that it is asked to
  # register, and after the deadline it stops working without one.
  #
  # The update server decides both moments and sends them as absolute times, so
  # no duration lives here. It also drops both once the registration is there.
  # That keeps the whole rule in one place and lets it change without a release
  # of this app.
  #
  # Both are absent until an answer arrives, and nothing is enforced then. That
  # is what a local installation needs, and it is also what an installation gets
  # while the update server is unreachable.
  def registration_reminder_at
    time_from(:registration_reminder_at)
  end

  def registration_due_at
    time_from(:registration_due_at)
  end

  # Whether to ask for the registration yet. False during the first days, so a
  # fresh installation can be explored before it is asked for anything.
  def registration_reminder_due?
    registration_reminder_at&.past? || false
  end

  def registration_grace_period_expired?
    registration_due_at&.past? || false
  end

  def latest
    fetch_and_cache_data_safely
  end

  def clear_cache!
    reset_verified_cache!
    cache_manager.delete
    cache_manager.clear_retry_throttle
    # Also clear sensor cache since permissions may have changed
    Sensor::Config.clear_cache!
  end

  def skip_prompt!
    cache_manager.skip_prompt!(skip_prompt_duration)
  end

  # How long the registration banner stays away after it is closed. Short, and
  # decided here: the deadline behind the banner belongs to the update server,
  # this is only how often the reminder is repeated until then.
  BANNER_SNOOZE = 24.hours
  private_constant :BANNER_SNOOZE

  def snooze_banner!
    cache_manager.snooze_banner!(BANNER_SNOOZE)
  end

  delegate :skipped_prompt?, :snoozed_banner?, to: :cache_manager

  private

  # Every moment in the answer is an ISO 8601 string.
  def time_from(key)
    value = latest[key]
    Time.zone.parse(value) if value.present?
  end

  def skip_prompt_duration
    entry = cached_entry
    (entry && entry[:data][:skip_prompt_duration]) || 24.hours
  end
end
