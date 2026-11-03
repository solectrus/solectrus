# The rules of the cars in one place: how SOLECTRUS reads the reports of a
# car, and from them its places and visits, its drives and its charges. Each
# value tells what it decides. The classes that apply a rule explain how they
# apply it (see docs/cars.md for the overview).
#
# A change of a value changes the result of a step of the daily build, so it
# needs a new VERSION of that step: Place::VisitDetection,
# ChargingSession::Detection or ChargingSession::OffsiteDetection.
module Car::Rules
  # The step of the curves of a day, the end of a bucket of 5 minutes (see
  # Sensor::Query::Helpers::Influx::DailyCurves)
  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

  # == Reports of a car

  # How late a car reports a change of its position or its connection: one
  # interval of a source that polls the car
  REPORT_LAG = 15.minutes
  public_constant :REPORT_LAG

  # The time after the arrival of a car at a place or a charge in which its
  # report of the drive can still come: REPORT_LAG and a bucket as a margin
  ARRIVAL = REPORT_LAG + BUCKET
  public_constant :ARRIVAL

  # The readings of one report of a car can come some seconds apart, like
  # the latitude and the longitude, or the odometer and the position
  REPORT_SPREAD = 1.minute
  public_constant :REPORT_SPREAD

  # How long after a charge a reading of the state of charge counts. A car
  # reports its state only while it is online, so a reading long after the
  # charge says nothing about it. The curves of a day reach further (see
  # ChargingSession::Curves::MARGIN).
  READING_DISTANCE = 2.hours
  public_constant :READING_DISTANCE

  # A car can report the state of charge some time after the odometer
  SOC_LAG = BUCKET
  public_constant :SOC_LAG

  # A change of one percentage point of the state of charge is the noise of
  # the reading, like a cold battery
  SOC_NOISE = 1
  public_constant :SOC_NOISE

  # A rise of the state of charge below this is noise (percentage points),
  # for the assignment of a charge at the wallbox to a car
  MIN_SOC_RISE = 1
  public_constant :MIN_SOC_RISE

  # == Places and visits

  # A position belongs to the nearest place within this distance (m)
  PLACE_RADIUS = 100
  public_constant :PLACE_RADIUS

  # A shorter stop gets no place of its own, for example a stop at a traffic
  # light. A car that reports less often needs a longer stop (see
  # STAY_INTERVALS).
  MIN_STAY = 30.minutes
  public_constant :MIN_STAY

  # A stop at a place that exists already needs less, for example a stop at
  # a shop. A traffic light is rarely within PLACE_RADIUS of a place.
  MIN_KNOWN_STAY = 15.minutes
  public_constant :MIN_KNOWN_STAY

  # The limit of a stop in intervals of the readings. A drive past has one
  # reading and lasts one interval, a visit has two readings and lasts two.
  # The half between them allows for an uneven interval.
  STAY_INTERVALS = 1.5
  public_constant :STAY_INTERVALS

  # The longest limit of a stop, so a car that reports rarely while it is
  # parked still makes a visit
  MAX_STAY_LIMIT = 3.hours
  public_constant :MAX_STAY_LIMIT

  # The rise of the odometer after a position that tells that the car left
  # it (km). The last reading of a drive can come shortly after the position
  # of the arrival, so a small rise is no departure.
  POSITION_MOVE = 1
  public_constant :POSITION_MOVE

  # A visit belongs to a drive up to this before its start or after its end.
  # A visit farther away belongs to another drive.
  VISIT_REACH = 1.hour
  public_constant :VISIT_REACH

  # == Drives

  # A longer gap of the readings before a rise of the odometer gives the
  # drive no start: nothing tells when it began
  MAX_DRIVE_GAP = 1.hour
  public_constant :MAX_DRIVE_GAP

  # A gap up to this before a rise of the odometer gives the drive an
  # estimated start. A longer gap says too little, like a night in which the
  # car did not report.
  MAX_ESTIMATED_GAP = 3.hours
  public_constant :MAX_ESTIMATED_GAP

  # A pause up to this joins two drives, because the state of charge can
  # stand still for a reading while the car drives. On the running day, a
  # fall up to this before now is a drive that still runs.
  MAX_DRIVE_PAUSE = 30.minutes
  public_constant :MAX_DRIVE_PAUSE

  # A fall of SOC_NOISE over a longer time is no drive, like a cold battery
  # while the car stands: a short drive falls by a point within some minutes
  SOC_NOISE_TIME = 30.minutes
  public_constant :SOC_NOISE_TIME

  # Readings of the odometer without a rise over this time within a pause
  # tell that the car stood, also where the stop was too short for a visit.
  # So does a position at a place where the car can have stood for this time,
  # up to the next reading elsewhere (see Car::DayTimeline#stays_of).
  MIN_STOP = 10.minutes
  public_constant :MIN_STOP

  # The highest average speed (km/h) that a drive without a start is assumed
  # to take
  MAX_ASSUMED_SPEED = 80
  public_constant :MAX_ASSUMED_SPEED

  # A shorter rise of the odometer (km) is no drive, like moving the car in
  # front of the house
  MIN_DRIVE_DISTANCE = 0.5
  public_constant :MIN_DRIVE_DISTANCE

  # The average speeds (km/h) of a drive that fit its time. A drive below
  # MIN_DRIVE_SPEED for longer than MIN_WINDOW is a short drive within a
  # window of the readings. Above MAX_DRIVE_SPEED, the time is too short.
  MIN_DRIVE_SPEED = 5
  MIN_WINDOW = 20.minutes
  MAX_DRIVE_SPEED = 150
  public_constant :MIN_DRIVE_SPEED, :MIN_WINDOW, :MAX_DRIVE_SPEED

  # The fall of the state of charge (percent) within DRIVE_DRAIN_TIME that
  # tells that an unplugged car drives, in the live view. A short drive stays
  # below it. A parked car loses less than a percent in an hour, but one
  # that heats or cools can lose more.
  DRIVE_DRAIN = 3
  DRIVE_DRAIN_TIME = 1.hour
  public_constant :DRIVE_DRAIN, :DRIVE_DRAIN_TIME

  # == Charges

  # A charge at the wallbox with less energy (kWh) is no session
  MIN_SESSION_KWH = 0.1
  public_constant :MIN_SESSION_KWH

  # A gap of the wallbox up to this does not end a charge at the wallbox
  MAX_SESSION_GAP = 15.minutes
  public_constant :MAX_SESSION_GAP

  # A charge with a slow rise reports the same state of charge for a while,
  # but not for longer than this
  MAX_CHARGE_PAUSE = 1.hour
  public_constant :MAX_CHARGE_PAUSE

  # A smaller rise of the state of charge (percentage points) is noise or a
  # short charge, so it proposes no offsite session
  MIN_OFFSITE_RISE = 5
  public_constant :MIN_OFFSITE_RISE

  # A smaller rise counts only while the car reports a connection, which
  # tells a short charge from noise (percentage points)
  MIN_CONNECTED_RISE = 3
  public_constant :MIN_CONNECTED_RISE

  # A longer step of a drive beside a charge can hold a charge of its own
  MAX_CHARGE_EDGE = 30.minutes
  public_constant :MAX_CHARGE_EDGE

  # An offsite session blocks a proposal in its time and this margin around
  # it, because an entered time is not exact and a car reports its state of
  # charge late
  PROPOSAL_MARGIN = 1.hour
  public_constant :PROPOSAL_MARGIN
end
