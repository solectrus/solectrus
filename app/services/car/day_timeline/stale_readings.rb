# The times in which a car repeated a stale state, for the timeline of a day
# (see Car::DayTimeline). The cloud of a car can send its last known state
# again and again while the car is offline, also while it drives or
# charges. These readings are no readings: the timeline leaves them out, so
# the time counts as a gap, like a car that did not report.
#
# A stale state shows where it ends: the odometer rises faster than a car
# drives (see Car::DayTimeline::Drive#too_fast?), and the state of charge
# changes in the same report. Before that, all readings of the car, the
# odometer, the state of charge and the plug, stood still. The readings
# after the first one of this run repeat it.
#
# A car whose odometer reports a drive late has a state of charge that fell
# while it drove, so its rise comes without a change of the state of
# charge. Its readings stay.
class Car::DayTimeline::StaleReadings
  # Each of the readings are [[Time, value], ...] of a sensor of the car,
  # empty without the sensor
  def initialize(odometer:, soc: [], plug: [])
    @odometer = Sensor::MeterReadings.new(odometer).call
    @soc = soc.sort_by(&:first)
    @plug = plug.sort_by(&:first)
  end

  # [[from, to], ...]: the readings after `from` and before `to` repeat the
  # state of `from`
  def call
    @odometer.each_cons(2).filter_map do |(before_time, before_value), (time, value)|
      next unless too_fast?(before_time, time, value - before_value) && soc_changed?(before_time, time)

      from = [@odometer, @soc, @plug].filter_map { run_start(it, before_time) }.max
      [from, time] if from < before_time
    end
  end

  private

  def too_fast?(from, to, distance) = distance.positive? && Car::DayTimeline::Drive.new(started_at: from, ended_at: to, distance:).too_fast?

  # Whether the first reading of the state of charge after `before_time`
  # comes with the rise at `time` and changes by more than SOC_NOISE
  def soc_changed?(before_time, time)
    before = @soc.rfind { |at, _| at <= before_time }
    after = @soc.find { |at, _| at > before_time }
    return false unless before && after

    after.first <= time + Car::Rules::SOC_LAG && (after.last - before.last).abs > Car::Rules::SOC_NOISE
  end

  # The time of the first reading of the run of the same value that holds at
  # `time`, or nil without a reading
  def run_start(readings, time)
    earlier = readings.select { |at, _| at <= time }
    return if earlier.empty?

    value = earlier.last.last
    earlier.reverse.take_while { it.last == value }.last.first
  end
end
