# Whether this installation has the full feature set, and why.
#
# The update server decides both. This class only reads its answer, so the
# phases stay in one place instead of being re-derived from single flags here.
#
# A grant this app cannot name still opens the features. The update server can
# add one at any time, and it reaches this app before the release that knows
# the name. Filtering here would lock the features of an installation the
# server just granted them to. Only the rendering needs the name, and it falls
# back to a text that gives none (see PremiumStatus::Component).
#
# There is no fallback to the older single flags. The cache key of the update
# check carries the app version, so an update makes the previous answer
# unreachable and the next check asks the server again.
class PremiumStatus
  # Only these two grants end. A subscription runs until it is cancelled, a
  # manual grant has no end at all. The list serves the simulation, which must
  # fabricate an end for them - the real answer carries one.
  TIMED_REASONS = %i[intro free_trial].freeze
  public_constant :TIMED_REASONS

  class << self
    delegate :trial_available?, to: UpdateCheck

    # Whether the update server answered at all. Without an answer there is no
    # reason, and the features are locked - but the installation did nothing to
    # deserve that, so the two cases must not read alike.
    delegate :unknown?, to: UpdateCheck
  end

  def self.reason
    UpdateCheck.premium_reason
  end

  # A grant whose end has passed no longer counts, even while the answer still
  # names it. The update server drops the reason the moment a grant ends, but
  # its last answer outlives that moment: it is served for another day when the
  # server cannot be reached (see Refresh::STALE_GRACE_PERIOD), and it waits in
  # a cache the installation itself holds. Reading the end costs nothing and
  # makes the answer say the same thing twice.
  def self.active?
    return false if reason.blank?

    ends_at.nil? || ends_at.future?
  end

  # The answer carries an end only for a grant that ends, so the answer decides
  # this and not a list of names here. A grant this app cannot name therefore
  # gets its countdown too.
  def self.ends_at
    UpdateCheck.premium_ends_at if reason.present?
  end
end
