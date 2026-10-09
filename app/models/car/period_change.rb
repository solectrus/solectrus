# What follows when the period of use of a car changes. A car counts for
# nothing outside its period, so the data of the days between the old and the
# new bounds must follow:
#
# - A wallbox session of the car outside the new period loses the car, also
#   a car that the user chose, and the next build runs the detection on
#   these days again (see ChargingSession::Detection). It also loses its
#   state of charge, which belongs to the car.
# - A proposal of an offsite session of the car outside the new period
#   goes, and the next build finds the proposals of these days again (see
#   ChargingSession::OffsiteDetection).
# - A visit of the car at a place outside the new period goes, and the next
#   build finds the visits of these days again (see Place::VisitDetection).
# - The summaries of the changed days go, so the next build makes them again
#   with the values of the car and the records of each step (see
#   Summary::Steps).
class Car::PeriodChange
  def initialize(car)
    @car = car
  end

  def call
    days = changed_days
    return if days.empty?

    release_sessions
    car.place_visits.where.not(date: car.active_from..car.active_until).delete_all
    days.each { Summary.where(date: it).delete_all }
  end

  private

  attr_reader :car

  # The sessions of the car outside the new period: a wallbox session loses
  # the car, a proposal goes
  def release_sessions
    outside = car.charging_sessions.where.not(started_at: car.period_times)
    outside.wallbox.update_all(car_id: nil, assigned_manually: false, soc_from: nil, soc_to: nil) # rubocop:disable Rails/SkipsModelValidations
    outside.proposals.delete_all
  end

  # The days between the old and the new value of each bound. A missing
  # bound reaches the installation date (a new car) or today (no last day).
  def changed_days
    [
      bound_range(:active_from, Rails.configuration.x.installation_date),
      bound_range(:active_until, Date.current),
    ].compact
  end

  def bound_range(attribute, open_end)
    change = car.saved_changes[attribute.to_s]
    return unless change

    dates = change.map { it || open_end }
    dates.min..dates.max
  end
end
