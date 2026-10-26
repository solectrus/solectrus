# An offsite session records a charge that took place (see ChargingSession).
# So it starts and ends before now, and it ends after its start. A session
# that keeps its time stays valid, like a session of the past that was saved
# before this rule.
module ChargingSession::EnteredTime
  extend ActiveSupport::Concern

  included do
    validate :time_in_past, if: -> { offsite? && changed.intersect?(%w[started_at ended_at]) }
  end

  private

  def time_in_past
    errors.add(:started_at, :in_future) if started_at&.future?
    return unless ended_at

    errors.add(:ended_at, :in_future) if ended_at.future?
    errors.add(:ended_at, :not_after_start) if started_at && ended_at <= started_at
  end
end
