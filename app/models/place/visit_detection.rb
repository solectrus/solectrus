# Finds the visits of each car at each place, as one more step of the daily
# build (see Summary::Steps). A visit lasts from the arrival of the car to its
# departure. The step writes the visits of its days and cuts them at
# midnight, like a daily summary, so a night at home has a row on each of the
# two days (see PlaceVisit).
#
# #call reads the positions of each car (see Sensor::Query::Positions) with
# one query for all days, and joins each position within Place::RADIUS of the
# stop before into this stop. It needs no database, so it can run in a thread
# of its own. #persist gives each stop its place (see Place.of), joins the
# stops at one place, and writes the visits of the days.
#
# Each stop has a limit (see #limit). A stop at no place and shorter than its
# limit is left out, for example a traffic light, and a shorter visit too,
# for example a drive past the home. Two visits at one place with a shorter
# time between them are one visit, for example with a wrong position between
# them.
#
# A position lasts until the next reading, at any age (see
# Sensor::Query::Positions). A car that reports every 15 minutes therefore
# stays 15 minutes at each position of a drive. The limit
# is at least Place::MIN_DURATION, and longer than one interval of the
# readings at the stop, so a visit needs two readings at the place. The
# interval comes from the readings themselves, so it can change from one day
# to the next, for example when the user asks the car more often.
class Place::VisitDetection
  # The step of the daily build (see Summary::Steps)
  KEY = :place_visits
  public_constant :KEY

  # Bump to build the visits of each day again
  VERSION = 1
  public_constant :VERSION

  # The visits come from the build alone (see Summary::Steps). The places
  # keep the names of the user, so they are no part of it.
  def self.derived = PlaceVisit

  # The limit of a stop in intervals of the readings. A drive past has one
  # reading and lasts one interval, a visit has two readings and lasts two.
  # The half between them allows for an uneven interval.
  INTERVALS = 1.5
  private_constant :INTERVALS

  # The longest limit, so a car that reports rarely while it is parked still
  # makes a visit. The query reads this much time before the first day and
  # after the last day. A visit over midnight then shows its full time up to
  # this length, so the limit gives the same result on both days.
  MAX_LIMIT = 3.hours
  private_constant :MAX_LIMIT

  # A stop: the positions that follow each other within Place::RADIUS of its
  # center. The center is the position with the longest time (`longest`).
  # The stop counts from its limit on (see #limit).
  Stop = Data.define(:latitude, :longitude, :from, :to, :longest, :limit) do
    def self.of(segment, limit:)
      new(latitude: segment.latitude, longitude: segment.longitude, from: segment.from, to: segment.to, longest: segment.duration, limit:)
    end

    def duration = to - from

    def long? = duration >= limit

    def near?(segment) = Geo.distance(latitude, longitude, segment.latitude, segment.longitude) <= Place::RADIUS

    # The stop up to the end of the segment
    def add(segment)
      return with(to: segment.to) if segment.duration <= longest

      with(latitude: segment.latitude, longitude: segment.longitude, to: segment.to, longest: segment.duration)
    end
  end
  public_constant :Stop

  # SOLECTRUS reads the positions of a car with a latitude and a longitude.
  # The positions need the permission of the sensors, like their query (see
  # Sensor::Query::Positions). Without it, the step waits, so it neither
  # removes the visits of a day nor marks the day as done.
  def self.enabled?
    Sensor::Cars.configured_numbers.any? { Sensor::Cars.located?(it) }
  end

  # The visits read the positions with a query of their own (see #positions),
  # so they ignore the shared curves (see Summary::Steps.shared)
  def initialize(dates, cars: Car.configured, curves: nil) # rubocop:disable Lint/UnusedMethodArgument
    @dates = dates.sort
    @cars = cars.select { it.located? && it.active_during?(@dates.first..@dates.last) }
  end

  attr_reader :dates

  # { car_id => [Stop, ...] } in the order of time, without a write. A car
  # has only the stops on the days of the step within its period of use.
  def call
    cars.to_h do |car|
      days = dates.select { car.active_on?(it) }.map { day(it) }
      [car.id, stops(positions(car)).select { |stop| days.any? { stop.from < it.end && it.begin < stop.to } }]
    end
  end

  # Writes the result of #call: the visits of each day, in place of the old
  # ones
  def persist(results)
    PlaceVisit.where(date: dates).delete_all

    rows = cars.flat_map { |car| rows_of(car, results.fetch(car.id, [])) }
    PlaceVisit.insert_all(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
  end

  private

  attr_reader :cars

  # One query for all days of the step, with MAX_LIMIT before and after
  def positions(car)
    Sensor::Query::Positions.new(
      latitude: car.sensor_name(:car_latitude),
      longitude: car.sensor_name(:car_longitude),
      odometer: car.sensor_name(:car_odometer),
      period: (day(dates.first).begin - MAX_LIMIT)..(day(dates.last).end + MAX_LIMIT),
    ).call
  end

  # A day from midnight to midnight, so the row of a day ends where the row
  # of the next day starts
  def day(date) = date.beginning_of_day...date.next_day.beginning_of_day

  # The limit of a stop comes from its arrival, and its departure lowers it
  # (see #limit)
  def stops(segments)
    segments.each_with_object([]) do |segment, stops|
      if stops.last&.near?(segment)
        stops[-1] = stops.last.add(segment)
      else
        stops[-1] = stops.last.with(limit: [stops.last.limit, limit(segment)].min) if stops.any?
        stops << Stop.of(segment, limit: limit(segment))
      end
    end
  end

  # The limit from the gap before a reading. A stop takes the shorter gap of
  # its arrival (before its first reading) and of its departure (before the
  # first reading after it). A gap is long after a time without reception,
  # or before the departure of a car that reports less often when parked.
  # A stop with one reading lasts as long as the gap of its departure, so it
  # always stays below its limit. The first reading of the query has no gap.
  def limit(segment)
    return Place::MIN_DURATION unless segment.gap

    (segment.gap * INTERVALS).clamp(Place::MIN_DURATION, MAX_LIMIT)
  end

  # The rows of the visits on the days of the step in the period of use of
  # the car
  def rows_of(car, stops)
    days = dates.select { car.active_on?(it) }

    visits(Place.of(stops).zip(stops)).flat_map do |visit|
      days.filter_map do |date|
        started_at = [visit.from, day(date).begin].max
        ended_at = [visit.to, day(date).end].min
        { date:, car_id: car.id, place_id: visit.place.id, started_at:, ended_at: } if started_at < ended_at
      end
    end
  end

  # A visit keeps the limit of its first stop
  Visit = Struct.new(:place, :from, :to, :limit)
  private_constant :Visit

  # The visits of the stops with a place. The stops at one place join first,
  # so short stops can add up. The short visits go next, and the visits at
  # one place join again, so a short visit at another place splits no visit.
  def visits(places_and_stops)
    visits = places_and_stops.filter_map { |place, stop| Visit.new(place, stop.from, stop.to, stop.limit) if place }

    join(join(visits).select { it.to - it.from >= it.limit })
  end

  # A visit joins the visit before at the same place after a time shorter
  # than the limit of the visit before
  def join(visits)
    visits.each_with_object([]) do |visit, result|
      last = result.last
      if last&.place == visit.place && visit.from - last.to < last.limit
        last.to = visit.to
      else
        result << visit.dup
      end
    end
  end
end
