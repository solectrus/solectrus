# The curves of the wallbox and of the cars on the days of a chunk of the
# daily build. The detection of the wallbox sessions
# (ChargingSession::Detection) and the proposals of the offsite sessions
# (ChargingSession::OffsiteDetection) read the same car sensors on the same
# days, so they share one program for them. Sensor::Summarizer gives both
# steps of a chunk the same object (see Summary::Steps.shared).
#
# The wallbox and the cars have a program each, and both run in the
# background as soon as a step needs them (see #start). The detection needs
# the curve of the wallbox first, for its periods and their energy, and the
# curves of the cars only at the end, for the car and the state of charge of
# a session. With one program for both, the detection waited for the curves
# of the cars before it could ask for the energy.
class ChargingSession::Curves
  WALLBOX = %i[wallbox_power wallbox_car_connected].freeze
  public_constant :WALLBOX

  CAR_ROLES = %i[car_battery_soc car_odometer car_connected car_latitude car_longitude].freeze
  private_constant :CAR_ROLES

  # How far the curves of a car on a day reach into the day before and the
  # day after. A charge over midnight needs the next morning (see
  # OffsiteDetection), and a late reading of a wallbox session needs
  # Detection::CarAssignment::READING_DISTANCE.
  MARGIN = 12.hours
  public_constant :MARGIN

  def initialize(dates, cars: Car.configured)
    wallbox = wallbox_requests
    car = car_request(dates, cars)

    @wallbox = Concurrent::Promises.delay { query(dates, wallbox) }
    @cars = Concurrent::Promises.delay { query(dates, [car]) }
  end

  # Starts the programs of the wallbox and of the cars in the background
  def start
    @wallbox.touch
    @cars.touch
  end

  # { date => { sensor_name => [[Time, value], ...] } } of the wallbox
  def wallbox = @wallbox.value!

  # { date => { sensor_name => [[Time, value], ...] } } of the cars. A
  # sensor of a car is a state, so its curve of each day starts with the
  # last reading before it (see Sensor::Query::Helpers::Influx::DailyCurves).
  def cars = @cars.value!

  private

  def query(dates, requests)
    Sensor::Query::Helpers::Influx::DailyCurves.new(dates, requests).call
  end

  # The curves of the wallbox, when the detection runs. A period needs the
  # buckets with power alone (see Detection::Periods).
  def wallbox_requests
    return [] unless ChargingSession::Detection.enabled?

    [
      { sensor_names: [:wallbox_power], positive: true },
      { sensor_names: [:wallbox_car_connected].select { Sensor::Config.configured?(it) } },
    ]
  end

  def car_request(dates, cars)
    days = dates.min..dates.max
    sensor_names = cars.select { it.active_during?(days) }.flat_map { |car| CAR_ROLES.map { car.sensor_name(it) } }

    { sensor_names: sensor_names.select { Sensor::Config.configured?(it) }, margin: MARGIN, state: true }
  end
end
