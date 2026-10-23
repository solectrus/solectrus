# The sessions to review: the wallbox sessions that are not assigned, and the
# proposals of the offsite sessions (see ChargingSession::Proposal). They count
# for no car until the admin assigns, confirms or dismisses them. The list of a
# kind shows them alone with its review switch.
module ChargingSession::Review
  extend ActiveSupport::Concern

  class_methods do
    # The sessions to review of a kind
    def to_review(kind) = kind.to_s == 'offsite' ? proposals : unassigned

    # Whether a car or the guest narrows the sessions to review of a kind. A
    # session that is not assigned belongs to no car and can be the charge of
    # any of them, so each selection names it. A proposal has its car.
    def review_by_car?(kind) = kind.to_s == 'offsite'

    # The number of the sessions to review of a kind in the timeframe, with the
    # car filter where it narrows them (see .listed). A charge over midnight
    # counts once (see .sums).
    def review_count(kind, timeframe:, filter:)
      listed(kind, timeframe:, filter: (filter if review_by_car?(kind)), review: true).sums.count
    end
  end
end
