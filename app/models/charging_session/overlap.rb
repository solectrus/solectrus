# A car charges at one station at a time, so a second offsite session of a
# car in the same time is a session entered twice (see ChargingSession)
module ChargingSession::Overlap
  extend ActiveSupport::Concern

  included do
    validate :no_overlap, if: -> { offsite? && car_id && !dismissed? && changed.intersect?(%w[car_id started_at ended_at dismissed]) }
  end

  private

  # A proposal does not count, the save removes it (see
  # ChargingSession::Proposal). Two sessions with the same start overlap also
  # without an end.
  def no_overlap
    return if started_at.nil?

    others = self.class.offsite.effective.where(car_id:).where.not(id:)
    overlapping = others.overlapping(started_at, ended_at || started_at).or(others.where(started_at:))
    errors.add(:started_at, :overlap) if overlapping.exists?
  end
end
