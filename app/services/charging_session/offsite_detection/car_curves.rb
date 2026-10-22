# The curves of one car on all days of a step of
# ChargingSession::OffsiteDetection, and what they tell about a charge. A
# sensor of a car is a state, which holds until its next reading (see the DSL
# `state`). A reading of the state of charge of 0 or less is no reading,
# because some collectors send 0 while the car is offline.
ChargingSession::OffsiteDetection::CarCurves = Data.define(:car, :soc, :odometer, :connected, :latitude, :longitude)

# The methods sit in a class body and not in the block of Data.define, like
# ChargingSession::Sums
class ChargingSession::OffsiteDetection::CarCurves
  # A longer step of a drive can hold a charge of its own
  MAX_EDGE = 30.minutes
  private_constant :MAX_EDGE

  # The steps of each charge: the runs of the state of charge (see
  # ChargingSession::SocRuns), cut at each step of a drive. Two stops at
  # chargers on one trip are two charges. A short step of a drive beside a
  # charge stays with it when no other rise lies beyond the step: a drive
  # does not raise the state of charge, so the charge began or ended within
  # the step. With readings every 20 minutes, these steps hold a large part
  # of the rise. The odometer can also report the end of a drive late, in
  # the first reading of the charge.
  def charges
    ChargingSession::SocRuns.new(soc).call.flat_map do |run|
      parts = run.slice_when { |step, next_step| drive?(step) || drive?(next_step) }

      # Each part with the two parts before it and after it
      [nil, nil, *parts, nil, nil].each_cons(5).filter_map do |far_before, before, steps, after, far_after|
        [*edge(before, far_before), *steps, *edge(after, far_after)] unless drive?(steps.first)
      end
    end
  end

  # Whether the car drove during a step
  def drive?((from, to)) = moved?(from, to)

  # Whether the odometer rises by more than Sensor::Query::Positions::MOVE
  # from one time to another
  def moved?(from, to)
    Sensor::Query::Positions.left?(state_at(odometer, from) || 0, state_at(odometer, to) || 0)
  end

  # :connected when the car reports a connection during the time,
  # :disconnected when it reports none, nil without a reading
  def connection(from, to)
    values = [state_at(connected, from), *connected.filter_map { |time, value| value if time > from && time <= to }].compact
    return if values.empty?

    values.any?(&:positive?) ? :connected : :disconnected
  end

  Position = Data.define(:latitude, :longitude)
  public_constant :Position

  # The position at a time, or nil. It is the last reading before the time,
  # at any age, of each coordinate. Like in
  # Sensor::Query::Positions, it ends when the odometer rises by more than
  # Sensor::Query::Positions::MOVE after it, because the car drove away. A
  # parked car can send nothing for days, while a source can stop to send
  # the position on the road.
  def position_at(time)
    since, lat = latitude.rfind { |reading_time, _| reading_time <= time }
    lon = state_at(longitude, time)
    Position.new(latitude: lat, longitude: lon) if lat && lon && !moved?(since, time)
  end

  # The state of charge of the reading at a time
  def soc_at(time)
    soc.find { |reading_time, _| reading_time == time }&.last
  end

  private

  # The short part of a drive beside a charge, unless the part beyond it
  # rises, because a drive between two charges belongs to neither (see
  # #charges)
  def edge(part, beyond)
    return unless part && drive?(part.first)

    from, to = part.first
    part if to - from <= MAX_EDGE && beyond.to_a.none? { |_, _, rise| rise.positive? }
  end

  # The last reading at or before a time, at any age
  def state_at(curve, time)
    curve.rfind { |reading_time, _| reading_time <= time }&.last
  end
end
