# When offsite sessions charged, for the power curve of a day (see
# Sensor::Chart::CarChargingPower). An offsite session has no power curve, so
# the curves of its car give the signs, in this order:
#
# 1. The state of charge rises: the energy follows the rise.
# 2. The car is plugged in and does not drive: the energy spreads evenly over
#    this time.
# 3. Otherwise: the energy spreads evenly over the whole time.
#
# The time of a session runs from its start to its end, or over its whole
# day without an end. Another session of the same car with a time of its
# own, at the wallbox or offsite, is no time of the session, because the car
# charges there then.
#
# A sensor of a car is a state, which holds until its next reading (see the
# DSL `state`). A car without a sensor gives no sign of it.
class ChargingSession::OffsiteProfile
  # The buckets of the time of a session, like the curves
  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

  # A charge below this is noise (percentage points of the state of charge)
  MIN_SOC_RISE = 2
  private_constant :MIN_SOC_RISE

  ROLES = %i[car_battery_soc car_connected car_odometer].freeze
  private_constant :ROLES

  def initialize(sessions)
    @sessions = sessions
  end

  attr_reader :sessions

  # [[from, to, Wh], ...] of all sessions, in buckets of up to 5 minutes
  def call
    sessions.flat_map do |session|
      buckets = buckets_of(span(session))
      weights = weights_of(session, buckets)
      wh_per_weight = session.kwh.to_f * 1000 / weights.sum

      buckets.zip(weights).filter_map { |(from, to), weight| [from, to, weight * wh_per_weight] if weight.positive? }
    end
  end

  private

  # The weights of the first sign that gives any, else the time of each
  # bucket
  def weights_of(session, buckets)
    soc_weights(session, buckets) ||
      free_weights(session, buckets, connected: curve(session, :car_connected), odometer: curve(session, :car_odometer)) ||
      free_weights(session, buckets) ||
      buckets.map { |from, to| to - from }
  end

  # [[from, to], ...] of 5 minutes from the start, the last one up to the end
  def buckets_of(span)
    (span.begin.to_i...span.end.to_i).step(BUCKET.to_i).map do |start|
      from = Time.zone.at(start)
      [from, [from + BUCKET, span.end].min]
    end
  end

  # The rise of the state of charge in each bucket, or nil without a rise. A
  # rise between two readings spreads evenly over the time between them.
  def soc_weights(session, buckets)
    rises = soc_rises(session)

    weights = buckets.map do |from, to|
      next 0.0 if elsewhere?(session, from, to)

      rises.sum { |rise_from, rise_to, rise| rise * overlap(from, to, rise_from, rise_to) / (rise_to - rise_from) }
    end
    weights if weights.sum.positive?
  end

  # [[from, to, rise], ...] between two readings of the state of charge in
  # the charges of the car (see ChargingSession::SocRuns). A charge below
  # MIN_SOC_RISE is noise, like 34 -> 35 -> 34 %. A rise that reaches into
  # another session of the car belongs to that session, also with its part
  # outside, because the readings come seldom.
  def soc_rises(session)
    ChargingSession::SocRuns.new(curve(session, :car_battery_soc))
      .call
      .select { |run| run.sum(&:last) >= MIN_SOC_RISE }
      .flatten(1)
      .select { |from, to, rise| rise.positive? && !elsewhere?(session, from, to) }
  end

  # The time of each bucket in which the car charges in no other session, is
  # plugged in and does not drive, or nil without such a bucket. Without
  # readings of the plug or the odometer, they give no sign.
  def free_weights(session, buckets, connected: [], odometer: [])
    drives = drives_of(odometer)

    weights = buckets.map do |from, to|
      free = !elsewhere?(session, from, to) && drives.none? { |drive_from, drive_to| overlap(from, to, drive_from, drive_to).positive? }
      free && plugged?(connected, to) ? to - from : 0.0
    end
    weights if weights.sum.positive?
  end

  # [[from, to], ...] between two readings of the odometer that rises by more
  # than a drive
  def drives_of(odometer)
    odometer.each_cons(2).filter_map do |(time, value), (next_time, next_value)|
      [time, next_time] if next_value - value > ChargingSession::Detection::CarAssignment::MIN_DRIVE
    end
  end

  # Whether the car is plugged in during the bucket that ends at the time.
  # Without readings of the plug, each bucket counts. Before the first
  # reading, its state is not known, so the car is not plugged in.
  def plugged?(connected, to)
    return true if connected.empty?

    connected.rfind { |time, _| time < to }&.last.to_f.positive?
  end

  def elsewhere?(session, from, to)
    timed_sessions[session.car_id].any? { it != session && overlap(from, to, it.started_at, it.ended_at).positive? }
  end

  def overlap(from, to, other_from, other_to)
    [[to, other_to].min - [from, other_from].max, 0].max
  end

  # The time of a session, or its whole day without an end
  def span(session)
    (@spans ||= {})[session] ||=
      if session.ended_at && session.ended_at > session.started_at
        session.started_at..session.ended_at
      else
        day = session.started_at.in_time_zone.to_date
        day.beginning_of_day..day.next_day.beginning_of_day
      end
  end

  # The readings of a car sensor on the days of a session. The curve of each
  # day starts with the last reading before it. A bucket of a curve carries
  # the end of its 5 minutes, so a reading goes to the start of its bucket.
  def curve(session, role)
    name = session.car.sensor_name(role)
    dates_of(session).flat_map { curves.dig(it, name) || [] }.uniq.sort_by(&:first).map { |time, value| [time - BUCKET, value] }
  end

  def dates_of(session)
    (span(session).begin.in_time_zone.to_date..(span(session).end - 1).in_time_zone.to_date).to_a
  end

  def curves
    @curves ||=
      Sensor::Query::Helpers::Influx::DailyCurves.new(
        sessions.flat_map { dates_of(it) }.uniq,
        [{ sensor_names:, state: true }],
      ).call
  end

  def sensor_names
    sessions.map(&:car).uniq.flat_map { |car| ROLES.map { car.sensor_name(it) } }.select { Sensor::Config.configured?(it) }
  end

  # { car_id => [session, ...] } of the sessions of the cars with a time of
  # their own: the wallbox sessions in the time of the offsite sessions, and
  # the offsite sessions with an end
  def timed_sessions
    @timed_sessions ||= begin
      spans = sessions.map { span(it) }
      ChargingSession
        .wallbox
        .where(car_id: sessions.map(&:car_id).uniq)
        .where(started_at: ...spans.map(&:end).max, ended_at: spans.map(&:begin).min..)
        .to_a
        .concat(sessions.select(&:ended_at))
        .group_by(&:car_id)
        .tap { it.default = [] }
    end
  end
end
