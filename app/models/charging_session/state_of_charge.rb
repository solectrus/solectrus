# The state of charge of the car at the start and at the end of a session
# (`soc_from`, `soc_to`), and the loss of the charge that follows from it.
# The detection writes it for a wallbox session, and the build for an offsite
# session (see ChargingSession::OffsiteDetection).
module ChargingSession::StateOfCharge
  extend ActiveSupport::Concern

  # The state of charge has whole percents, so a smaller rise gives no loss
  LOSS_MIN_RISE = 20
  private_constant :LOSS_MIN_RISE

  # Fewer sessions give no energy of a percent (see .kwh_per_percent)
  MIN_SESSIONS = 5
  private_constant :MIN_SESSIONS

  included do
    # The state of charge belongs to the car of the session. A new build
    # reads it for the car of the user again.
    before_save -> { self.soc_from = self.soc_to = nil }, if: -> { persisted? && will_save_change_to_car_id? }
  end

  class_methods do
    # { car id => the charged energy (kWh) that raises the state of charge of
    # the car by one percentage point }: the median of its sessions, nil
    # with fewer than MIN_SESSIONS. It holds the capacity and the loss of a
    # charge in one number, so it needs no capacity. An offsite session with
    # the estimate of its rise as its energy has no loss, so it does not
    # count (see ChargingSession::Proposal.estimate).
    def kwh_per_percent(cars)
      rows =
        where(car: cars).effective.where.not(soc_from: nil).where.not(soc_to: nil).where(kwh: 0.001..)
          .pluck(:car_id, :kind, :kwh, :soc_from, :soc_to)

      cars.to_h do |car|
        ratios = rows.filter_map { |car_id, *row| kwh_per_percent_of(*row, car.battery_kwh) if car_id == car.id }
        [car.id, (ratios.sort[ratios.size / 2] if ratios.size >= MIN_SESSIONS)]
      end
    end

    private

    # The energy of a percent of one session, nil for a small rise and for an
    # offsite session with an estimated energy
    def kwh_per_percent_of(kind, kwh, soc_from, soc_to, capacity)
      rise = soc_to - soc_from
      return if rise < LOSS_MIN_RISE
      return if kind == 'offsite' && kwh == estimate(soc_from, soc_to, capacity)

      (kwh / rise).to_f
    end
  end

  # The rise of the state of charge in percentage points, or nil
  def soc_rise
    soc_to - soc_from if soc_from && soc_to
  end

  # The share of the energy that did not reach the battery, from the rise of
  # the state of charge and the capacity of the car. A proposal has no
  # measured energy, so it has no loss. An ongoing session has no state at
  # its end yet (see ChargingSession::Ongoing).
  def loss
    1 - (soc_rise * car.battery_kwh / 100 / kwh) if loss?
  end

  private

  def loss?
    return false if proposal? || ongoing? || car&.battery_kwh.nil? || !kwh&.positive?

    soc_rise.to_f >= LOSS_MIN_RISE
  end
end
