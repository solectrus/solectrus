# The steps of the daily build besides the values of the sensors, for example
# the detection of the charging sessions (docs/cars.md). A step reads the
# InfluxDB data of its days and writes records of its own.
#
# A step runs on each day that the build makes, and only there. So a summary
# holds the values and the records of each step, and a day is built in full
# or not at all. What changes the result of a step removes the summaries:
#
# - a new VERSION of a step, a step with something to do now, or a new sensor
#   of a step (see Sensor::SummaryInvalidator)
# - a new home (see Place)
# - a new period of use of a car, on the changed days (see Car::PeriodChange)
#
# A step does not ask for the permission of its sensors. A sponsorship opens
# pages, and the records are there before it.
#
# A step class answers:
#
#   KEY         its name in the configuration of the summaries
#   VERSION     bump it to build each day again
#   .enabled?   whether the configuration gives the step anything to do
#   .sensor_names
#               the sensors that the step reads, also the ones without a
#               configuration
#   .derived    the model whose records come from the build alone, which a
#               reset of the summaries empties, or nil when the records
#               keep changes of the user
#   .new(dates, **shared)
#               a step for the given days, with what the steps of a chunk
#               share (see .shared)
#   #call       reads InfluxDB and returns a result, without the database,
#               so it can run in a thread of its own
#   #persist    writes the result, inside the transaction of the build
module Summary::Steps
  # The names of the step classes, so a step loads only when it is needed
  # A step writes in this order, so a later step can read the records of an
  # earlier one: the proposals of offsite sessions read the wallbox sessions.
  CLASSES = %w[ChargingSession::Detection Place::VisitDetection ChargingSession::OffsiteDetection].freeze
  private_constant :CLASSES

  def self.all = CLASSES.map(&:constantize)

  def self.[](key) = all.find { key.to_sym == it::KEY } || raise(ArgumentError, "Unknown step: #{key}")

  # The models whose records come from the build alone (see Summary.reset!)
  def self.derived = all.filter_map(&:derived)

  # The steps with something to do
  def self.enabled = all.select(&:enabled?)

  # What the steps of a chunk share, as the keywords of .new: the curves of
  # the wallbox and of the cars, which the detection and the proposals both
  # read (see ChargingSession::Curves). A step that does not read them
  # ignores them.
  def self.shared(dates) = { curves: ChargingSession::Curves.new(dates) }

  # The version of each step with something to do, for the configuration of
  # the summaries (see Sensor::SummaryInvalidator)
  def self.versions = enabled.to_h { [it::KEY.to_s, it::VERSION] }

  # The sensors that the steps with something to do read
  def self.sensor_names = enabled.flat_map(&:sensor_names).uniq
end
