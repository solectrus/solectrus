# What follows when the period of use of a car changes. A car counts for
# nothing outside its period, so the data of the days between the old and the
# new bounds must follow:
#
# - The summaries of the changed days go, so the next build makes them again
#   with the values of the car.
class Car::PeriodChange
  def initialize(car)
    @car = car
  end

  def call
    days = changed_days
    return if days.empty?

    days.each { Summary.where(date: it).delete_all }
  end

  private

  attr_reader :car

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
