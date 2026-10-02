# Creates a car for each configured number without a car, so a user with one
# car has nothing to do. The configuration decides which numbers exist (see
# Sensor::Cars.configured_numbers), and the table holds the name, the period
# and the color of each.
#
# It is not part of Sensor::Config, because a database write at configuration
# time couples the two layers. It runs on the first request that needs a car
# instead, and it tolerates a missing table, because a migration can run
# later. Two parallel requests make one record, because the insert ignores an
# existing id.
class Car::Provisioning
  def self.call = new.call

  # The cars of the configured numbers, ordered by number
  def call
    return Car.none unless Car.table_exists?

    numbers = Sensor::Cars.configured_numbers
    cars = Car.where(id: numbers).ordered
    missing = numbers - cars.map(&:id)
    if missing.any?
      active_from = Rails.configuration.x.installation_date
      Car.insert_all(missing.map { { id: it, active_from: } }, unique_by: :id) # rubocop:disable Rails/SkipsModelValidations
      cars.reset
    end

    cars
  end
end
