# The steps of the daily build besides the values of the sensors, for example
# the detection of the charging sessions (docs/cars.md). A step reads the
# InfluxDB data of its days and writes records of its own.
#
# A step has a version. The summary of a day stores the version of each step
# that ran on it (summaries.steps), so a new version runs the step again on
# each day, and only the step. A page asks only for the steps whose records it
# reads, so a new version of a step rebuilds no day for the other pages.
#
# A step class answers:
#
#   KEY         its name in summaries.steps
#   VERSION     bump it to run the step on each day again
#   .enabled?   whether the configuration gives the step anything to do
#   .derived    the model whose records come from the build alone, which a
#               reset of the summaries empties, or nil when the records
#               keep changes of the user
#   .new(dates) a step for the given days
#   #call       reads InfluxDB and returns a result, without the database,
#               so it can run in a thread of its own
#   #persist    writes the result, inside the transaction of the build
module Summary::Steps
  # The names of the step classes, so a step loads only when it is needed
  CLASSES = %w[ChargingSession::Detection Place::VisitDetection].freeze
  private_constant :CLASSES

  def self.all = CLASSES.map(&:constantize)

  def self.keys = all.map { it::KEY }

  def self.[](key) = all.find { key.to_sym == it::KEY } || raise(ArgumentError, "Unknown step: #{key}")

  # The models whose records come from the build alone (see Summary.reset!)
  def self.derived = all.filter_map(&:derived)

  # The steps with something to do
  def self.enabled = all.select(&:enabled?)

  # The version of each of the steps, as summaries.steps stores it after a
  # build
  def self.versions(steps = all) = steps.to_h { [it::KEY.to_s, it::VERSION] }

  # The steps of a parameter like "charging_sessions,places". An unknown name
  # is left out, so a hand-made address cannot fail.
  def self.parse(param)
    names = param.to_s.split(',').map(&:strip)
    keys.select { names.include?(it.to_s) }
  end
end
