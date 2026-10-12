# The periods of a day in which the wallbox charged, found on the 5-minute
# means of its curves. A period is a continuous time with wallbox_power > 0.
# A gap of GAP or less does not end it, because load management and PV
# surplus control make such gaps.
#
# wallbox_car_connected bridges a longer gap, but it never moves an end: the
# first bucket with power is the start, and the last is the end. Otherwise a
# charge before the sensor reports the connection loses its energy, and the
# balance of the day breaks.
class ChargingSession::Detection::Periods
  BUCKET = 5.minutes
  public_constant :BUCKET

  # A gap of this length or less does not end a period
  GAP = 15.minutes
  public_constant :GAP

  # `power` and `connected` are the curves of the day: [[Time, value], ...],
  # each Time the end of its bucket
  def initialize(date, power:, connected: [])
    @day = Timeframe.new(date.iso8601)
    @power = power
    @connected = connected
  end

  # [[from, to], ...]
  def call
    power.each_with_object([]) do |(stamp, watt), periods|
      next unless watt.positive?

      from = [stamp - BUCKET, day.beginning].max
      to = [stamp, day.ending].min
      last = periods.last

      if last && bridged?(last[1], from)
        last[1] = to
      else
        periods << [from, to]
      end
    end
  end

  private

  attr_reader :day, :power, :connected

  # Whether a gap does not end the period: it is short, or the gap has a
  # reading of the connection, and each of them reports a connected car
  def bridged?(last_end, next_start)
    return true if next_start - last_end <= GAP

    readings = connected.select { |time, _| time > last_end && time - BUCKET < next_start }
    readings.any? && readings.all? { it.last.positive? }
  end
end
