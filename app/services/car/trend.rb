# The trend of a chart of the car page, like car_distance. Such a sensor has
# no daily value of its own, so the base value comes from the report of the
# earlier period (see Car::Report#value), which Car::ChangesOverview passes
# as `base_data`, and the first day is the first day of use.
class Car::Trend < Trend
  # The first day of the cars or, with `guest`, of the guest sessions: a
  # car counts from its first day of use, the guest from its first session.
  # Nil without either.
  def self.first_day_of_use(cars:, guest:)
    [*cars.map(&:active_from), (first_guest_date if guest)].compact.min
  end

  def self.first_guest_date
    ChargingSession.wallbox.effective.where(car_id: nil, guest: true).minimum(:started_at)&.to_date
  end
  private_class_method :first_guest_date

  # Nil without a value, for example without a rate
  def base_value
    @base_value ||= (base_data.value(sensor.name) if valid?)
  end
end
