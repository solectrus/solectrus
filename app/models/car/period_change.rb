# What follows when the period of use of a car changes. A car counts for
# nothing outside its period, so the data of the days between the old and the
# new bounds must follow:
#
# - A wallbox session of the car outside the new period loses the car, also
#   a car that the user chose, and the next build runs the detection on
#   these days again (see ChargingSession::Detection).
# - A daily value of the car outside the new period goes (see
#   Sensor::Summarizer).
# - A visit of the car at a place outside the new period goes, and the next
#   build finds the visits of these days again (see Place::VisitDetection).
# - A day that the period gains has no value of the car, so its summary goes
#   and the next build makes it again.
class Car::PeriodChange
  def initialize(car)
    @car = car
  end

  def call
    days = changed_days
    return if days.empty?

    car
      .charging_sessions
      .wallbox
      .where.not(started_at: car.period_times)
      .update_all(car_id: nil, assigned_manually: false) # rubocop:disable Rails/SkipsModelValidations

    SummaryValue.where(field: sensor_names).where.not(date: car.active_from..car.active_until).delete_all
    Summary.where(date: gained_days(days)).delete_all
    car.place_visits.where.not(date: car.active_from..car.active_until).delete_all
    Summary.reset_step(ChargingSession::Detection::KEY, days)
    Summary.reset_step(Place::VisitDetection::KEY, days)
  end

  private

  attr_reader :car

  # The sensors of the car with a daily value. car_connected has none.
  def sensor_names
    Sensor::Cars::ROLES.map { car.sensor_name(it) }.select { Sensor::Registry[it].store_in_summary? }.map(&:to_s)
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

  # The days of the new period that the old period did not hold
  def gained_days(days)
    days.flat_map(&:to_a).select { car.active_on?(it) && !active_before_on?(it) }
  end

  # Whether the period before the save held the date. A new car had none.
  def active_before_on?(date)
    from = car.attribute_before_last_save(:active_from)
    to = car.attribute_before_last_save(:active_until)

    from.present? && from <= date && (to.nil? || to >= date)
  end
end
