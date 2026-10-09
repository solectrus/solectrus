# The proposals of offsite sessions (see ChargingSession::OffsiteDetection).
# A proposal is an offsite session without the mark `assigned_manually`: the
# daily build found the charge, and the user did not decide yet. A save
# through the model accepts it, because it sets the mark. A dismissed
# proposal keeps its row with the mark, so the next build does not make it
# again.
#
# An offsite session of a car with the mark blocks a proposal of this car in
# its time (see #blocked_period), so the build makes no second session of an
# entered charge.
module ChargingSession::Proposal
  extend ActiveSupport::Concern

  # An offsite session blocks a proposal in its time and this margin around
  # it, because an entered time is not exact and a car reports its state of
  # charge late
  BLOCK_MARGIN = 1.hour
  public_constant :BLOCK_MARGIN

  included do
    # The open proposals of the build
    scope :proposals, -> { offsite.where(assigned_manually: false) }

    # The sessions that count: each wallbox session and each offsite
    # session that the user entered or accepted, but no proposal and no
    # dismissed one
    scope :effective,
          lambda {
            where(dismissed: false).where(arel_table[:kind].eq('wallbox').or(arel_table[:assigned_manually].eq(true)))
          }

    # The sessions whose time reaches into the given times. A session
    # without an end lasts a moment.
    scope :overlapping, ->(from, to) { where(started_at: ...to).where('COALESCE(ended_at, started_at) > ?', from) }

    # A new or changed offsite session replaces the proposals of its time
    after_save :remove_blocked_proposals, if: -> { offsite? && !dismissed? }
  end

  class_methods do
    # The energy of a rise of the state of charge in the battery, in kWh, or
    # nil without the capacity. A receipt shows more, because the charge
    # loses energy.
    def estimate(soc_from, soc_to, battery_kwh)
      return unless soc_from && soc_to && battery_kwh

      kwh = ((soc_to - soc_from) * battery_kwh / 100).round(3)
      kwh if kwh.positive?
    end

    # Gives each proposal of the car a new estimate from its state of charge,
    # after a change of the capacity of the car. It reads no InfluxDB data.
    def reestimate(car)
      proposals.where(car:).find_each do |proposal|
        proposal.update_columns(kwh: estimate(proposal.soc_from, proposal.soc_to, car.battery_kwh)) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  # An offsite session that the build found and the user did not accept or
  # dismiss yet. A new session that the user enters is no proposal.
  def proposal? = persisted? && offsite? && !assigned_manually? && !dismissed?

  # The user dismisses a proposal
  def dismiss!
    update!(dismissed: true)
  end

  # The time in which this offsite session blocks a proposal of its car: its
  # time with BLOCK_MARGIN around it, or without an end its whole day,
  # because a session from the history often has its day alone
  def blocked_period
    return date.beginning_of_day...date.next_day.beginning_of_day unless ended_at

    (started_at - BLOCK_MARGIN)...(ended_at + BLOCK_MARGIN)
  end

  private

  def remove_blocked_proposals
    period = blocked_period
    self.class.proposals.where(car_id:).where.not(id:).overlapping(period.begin, period.end).delete_all
  end
end
