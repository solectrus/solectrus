# The plausible readings of a meter, like a car odometer (see
# Sensor::Query::Helpers::Influx::DailyDiffs). A meter never runs backwards,
# so a reading below the one before it is wrong: for example a 0 that a
# collector sends while the car is offline. The jump back to the right
# reading would add the full odometer to the distance of a day.
#
# A reading of 0 or less is never plausible. A reading below the reading
# before it is left out, unless the reading after it confirms the change:
# then the meter changed for good, for example after a new source. The day
# of such a change gets no increase, because a daily diff is never
# negative.
class Sensor::MeterReadings
  # Rounding of the source, so a small step back is no error (in the unit
  # of the meter)
  TOLERANCE = 1
  private_constant :TOLERANCE

  # `readings` are [[Time, value], ...]
  def initialize(readings)
    @readings = readings.sort_by(&:first)
  end

  # The plausible readings, sorted by time
  def call
    positive = readings.select { |_, value| value.to_f.positive? }

    positive.each_with_index.with_object([]) do |(reading, index), kept|
      before = kept.last
      after = positive[index + 1]
      kept << reading if before.nil? || step?(before, reading) || confirmed?(before, reading, after)
    end
  end

  private

  attr_reader :readings

  # Whether the reading after a step back stays with it, so the meter
  # changed for good
  def confirmed?(before, reading, after)
    after.present? && !step?(before, after) && step?(reading, after)
  end

  # Whether the meter can go from one reading to the other
  def step?(from, to)
    to.last - from.last >= -TOLERANCE
  end
end
