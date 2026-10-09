# The curves of one car on all days of a step of
# ChargingSession::OffsiteDetection, and what they tell about a charge. A
# sensor of a car is a state, which holds until its next reading (see the DSL
# `state`). A reading of the state of charge of 0 or less is no reading,
# because some collectors send 0 while the car is offline.
ChargingSession::OffsiteDetection::CarCurves = Data.define(:car, :soc, :odometer, :connected, :latitude, :longitude)

# The methods sit in a class body and not in the block of Data.define, like
# ChargingSession::Sums
class ChargingSession::OffsiteDetection::CarCurves
  # The steps of each charge: the runs of the state of charge (see
  # ChargingSession::SocRuns), cut at each step of a drive, which belongs to
  # no charge. Two stops at chargers on one trip are two charges.
  def charges
    ChargingSession::SocRuns.new(soc).call.flat_map do |run|
      run.slice_when { |step, next_step| drive?(step) || drive?(next_step) }
         .reject { |steps| steps.one? && drive?(steps.first) }
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
  # at any age, with the latitude and the longitude of the same time. Like in
  # Sensor::Query::Positions, it ends when the odometer rises by more than
  # Sensor::Query::Positions::MOVE after it, because the car drove away. A
  # parked car can send nothing for days, while a source can stop to send
  # the position on the road.
  def position_at(time)
    since, lat = latitude.rfind { |reading_time, _| reading_time <= time }
    lon = since && longitude.to_h[since]
    Position.new(latitude: lat, longitude: lon) if lon && !moved?(since, time)
  end

  # The state of charge of the reading at a time
  def soc_at(time)
    soc.find { |reading_time, _| reading_time == time }&.last
  end

  private

  # The last reading at or before a time, at any age
  def state_at(curve, time)
    curve.rfind { |reading_time, _| reading_time <= time }&.last
  end
end
