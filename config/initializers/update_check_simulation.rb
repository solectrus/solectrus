# Simulates any phase of the registration and premium lifecycle, so the whole
# flow can be walked through by hand instead of waiting days for it.
#
# Development only. In test and production this file does nothing, and a real
# installation always gets the signed answer of the update server.
#
# .env.development.local holds ready-made scenarios. Each one sets all six
# variables, so no value survives from another scenario:
#
#   SIMULATE_INSTALLED_DAYS_AGO    Age of the installation in days. From it the
#                                  simulation derives the two registration
#                                  deadlines the update server would send: the
#                                  banner after 3 days, the lockout after 7.
#                                  Without it a local installation gets no
#                                  deadline and is never locked out. A
#                                  registered installation gets none either.
#   SIMULATE_REGISTRATION_STATUS   unregistered | pending | complete | unknown.
#                                  Default: complete. "unknown" is the answer
#                                  that never arrived - the update server never
#                                  sends that value, this app sets it itself
#                                  when a request fails.
#   SIMULATE_PREMIUM_REASON        Why the full feature set applies.
#                                  sponsoring | eligible_for_free | free_trial |
#                                  intro | development | none.
#                                  Default: development. Any other name works
#                                  too and opens the features: the update server
#                                  owns this list and can add a name at any
#                                  time.
#   SIMULATE_PREMIUM_DAYS_LEFT     Days until intro or free_trial ends. Every
#                                  other reason ignores it. Default: 10
#   SIMULATE_TRIAL_AVAILABLE       true = the free month is still unused
#   SIMULATE_PROMPT                true = the server asks for a sponsorship
#
# If a change seems to have no effect, run `bin/spring stop` first - a
# preloaded application keeps the environment it booted with.
return unless Rails.env.development?

module UpdateCheckSimulation
  def fallback_data
    @fallback_data ||= {
      version: Rails.configuration.x.git.commit_version,
      registration_status: simulated('REGISTRATION_STATUS') || 'complete',
      trial_available: simulated?('TRIAL_AVAILABLE'),
      prompt: simulated?('PROMPT'),
      **simulated_registration,
      **simulated_premium,
    }.compact_blank.freeze
  end

  private

  # The update server owns these durations, this only mirrors them so the
  # phases can be walked through. A local installation without a simulated age
  # gets no deadline at all and is never locked out.
  REGISTRATION_REMINDER_AFTER = 3.days
  REGISTRATION_DEADLINE = 7.days
  private_constant :REGISTRATION_REMINDER_AFTER, :REGISTRATION_DEADLINE

  # Only these two states get a deadline, as on the server. A registered
  # installation owes nothing. "unknown" never carries one either, because it
  # marks a failed request and a failed request has no fields at all.
  PENDING_STATES = %w[unregistered pending].freeze
  private_constant :PENDING_STATES

  def simulated_registration
    days_ago = simulated('INSTALLED_DAYS_AGO')
    return {} unless days_ago
    return {} unless simulated('REGISTRATION_STATUS').in?(PENDING_STATES)

    installed_at = days_ago.to_i.days.ago
    {
      registration_reminder_at:
        (installed_at + REGISTRATION_REMINDER_AFTER).iso8601,
      registration_due_at: (installed_at + REGISTRATION_DEADLINE).iso8601,
    }
  end

  def simulated(name)
    ENV.fetch("SIMULATE_#{name}", nil).presence
  end

  def simulated?(name)
    simulated(name).in?(%w[true 1 yes])
  end

  def simulated_premium
    reason = simulated('PREMIUM_REASON') || 'development'
    return {} if reason == 'none'

    { premium_reason: reason, premium_ends_at: (simulated_ends_at if timed?(reason)) }
  end

  def timed?(reason)
    reason.to_sym.in?(PremiumStatus::TIMED_REASONS)
  end

  def simulated_ends_at
    (simulated('PREMIUM_DAYS_LEFT') || 10).to_i.days.from_now.iso8601
  end
end

# UpdateCheck lives in app/ and is reloaded, so this runs on every reload.
Rails.application.config.to_prepare do
  UpdateCheck.prepend(UpdateCheckSimulation) unless UpdateCheck < UpdateCheckSimulation
end
