# The state of charge of the car at the start and at the end of a session
# (`soc_from`, `soc_to`), and the loss of the charge that follows from it.
# The detection writes it for a wallbox session, and the build for an offsite
# session (see ChargingSession::OffsiteDetection).
module ChargingSession::StateOfCharge
  extend ActiveSupport::Concern

  # The state of charge has whole percents, so a smaller rise gives no loss
  LOSS_MIN_RISE = 20
  private_constant :LOSS_MIN_RISE

  included do
    # The state of charge belongs to the car of the session. A new build
    # reads it for the car of the user again.
    before_save -> { self.soc_from = self.soc_to = nil }, if: -> { persisted? && will_save_change_to_car_id? }
  end

  # The rise of the state of charge in percentage points, or nil
  def soc_rise
    soc_to - soc_from if soc_from && soc_to
  end

  # The share of the energy that did not reach the battery, from the rise of
  # the state of charge and the capacity of the car. A proposal has no
  # measured energy, so it has no loss.
  def loss
    1 - (soc_rise * car.battery_kwh / 100 / kwh) if loss?
  end

  private

  def loss?
    return false if proposal? || car&.battery_kwh.nil? || !kwh&.positive?

    soc_rise.to_f >= LOSS_MIN_RISE
  end
end
