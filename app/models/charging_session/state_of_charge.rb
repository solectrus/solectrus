# The state of charge of the car at the start and at the end of a session
# (`soc_from`, `soc_to`), the loss of the charge that follows from it, and
# whether it fits the charged energy.
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

  # Each end of the rise can be off by one point, because the state of
  # charge has whole percents (see #soc_mismatch?)
  SOC_TOLERANCE = 2
  private_constant :SOC_TOLERANCE

  # The rise contradicts the charged energy when the energy that it puts into
  # the battery is surely below half of it or above one and a half times it.
  # A smaller difference is normal: the scale of the state of charge changes
  # with the temperature of the battery, so a point can hold a quarter less
  # energy in winter.
  MISMATCH = 0.5
  private_constant :MISMATCH

  # A full car can take energy without a rise, to balance or to heat its
  # battery
  FULL = 99
  private_constant :FULL

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

  # Whether the rise contradicts the charged energy, for example 75 -> 75 %
  # with 20 kWh. The car then reported no current values during the charge.
  def soc_mismatch?
    return false unless soc_checkable?

    too_small = battery_share(soc_rise + SOC_TOLERANCE) < 1 - MISMATCH && soc_to < FULL
    too_large = battery_share([soc_rise - SOC_TOLERANCE, 0].max) > 1 + MISMATCH
    too_small || too_large
  end

  # The share of the energy that did not reach the battery, from the rise of
  # the state of charge and the capacity of the car. It is negative when the
  # state of charge rose more than the energy explains, nil for a rise that
  # contradicts the energy.
  def loss
    1 - battery_share(soc_rise) if loss?
  end

  private

  # A proposal has no measured energy. An ongoing session has no state at its
  # end yet (see ChargingSession::Ongoing).
  def soc_checkable?
    !proposal? && !ongoing? && car&.battery_kwh.present? && kwh&.positive? && soc_rise.present?
  end

  # The share of the charged energy that a rise puts into the battery
  def battery_share(rise) = rise * car.battery_kwh / 100 / kwh

  def loss?
    soc_checkable? && soc_rise >= LOSS_MIN_RISE && !soc_mismatch?
  end
end
