# The range of a car without a range sensor, estimated from its state of
# charge: the charged energy of a percentage point (see
# ChargingSession.kwh_per_percent) gives the distance of a percentage point
# at the energy per km of the recent days (see Car::Driving#rate). Both are
# energy at the charger, so the loss of a charge cancels out, and the
# estimate needs no capacity. The rate keeps the season and the recent way
# of driving.
class Car::RangeEstimate
  def initialize(cars)
    @cars = cars
  end

  # The distance (km) of one percentage point of the state of charge, nil
  # without enough sessions or without a rate. A car in use for less than
  # the window has no estimate, because a few days give a wrong rate: the
  # car drives on the charge it came with.
  def km_per_percent(car)
    return if [car.active_from, min_date].compact.max > today - Car::Driving::MARGIN_DAYS

    kwh = ledger.kwh_per_percent(car)
    rate = driving.rate(car, today) if kwh
    kwh * 1000 / rate.energy_wh if rate
  end

  private

  attr_reader :cars

  def today = @today ||= Date.current

  def min_date = Rails.application.config.x.installation_date

  def ledger
    @ledger ||= Car::Ledger.new(cars, Car::Driving.window_reach(today..today, min_date:))
  end

  def driving
    @driving ||= Car::Driving.new(ledger, min_date:)
  end
end
