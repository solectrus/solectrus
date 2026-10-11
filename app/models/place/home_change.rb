# What follows when home comes or goes. The detection of the wallbox
# sessions and the proposals of the offsite sessions read home, but only at
# a position of a car (see ChargingSession::Detection::CarAssignment#away?
# and ChargingSession::OffsiteDetection#at_home?). So only the days on which
# a car can have a position change, and their summaries go. The next build
# makes them again with the records of each step (see Summary::Steps).
#
# A position lasts until the next reading, at any age, so a parked car has a
# position also on a day without a reading. Only the days before the first
# position of a car are certainly without one.
#
# The values of the sensors do not change, so no cache must go.
class Place::HomeChange
  def call
    days = changed_days
    return Summary.reset! unless days

    days.each { Summary.where(date: it).delete_all }
  end

  private

  # The days of each car with a location, from its first position to the end
  # of its period of use, or nil when InfluxDB cannot tell the first position
  def changed_days
    cars = Car.configured.select { Sensor::Cars.located?(it.id, check_policy: false) }
    return [] if cars.empty?

    first_seen = Sensor::Query::FirstSeen.new(cars.map { it.sensor_name(:car_latitude) }).call
    cars.filter_map do |car|
      first = first_seen[car.sensor_name(:car_latitude)]
      next unless first

      from = [car.active_from, first.to_date].max
      to = car.active_until || Date.current
      from..to if from <= to
    end
  rescue StandardError => e
    # Rebuilding without need costs time, wrong summaries cost trust
    Rails.logger.warn "Cannot read the first positions of the cars: #{e.message}"
    nil
  end
end
