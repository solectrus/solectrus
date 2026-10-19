# The periods of a day in which the wallbox charged, found on the 5-minute
# means of its curves. A period is a continuous time with wallbox_power > 0.
# A gap of GAP or less does not end it, because load management and PV
# surplus control make such gaps.
#
# wallbox_car_connected bridges a longer gap, but it never moves an end: the
# first bucket with power is the start, and the last is the end. Otherwise a
# charge before the sensor reports the connection loses its energy, and the
# balance of the day breaks.
#
# A bucket without a reading is no data, not 0 W: a collector can fail for
# an hour while the car charges. Such a bucket does not end a period, so a
# gap without data does not split a charge. A period also reaches across
# such a gap at each end, to the next bucket with data. The daily sum
# integrates across the gap from the last value to the next one, so the
# sessions keep the balance of the day.
class ChargingSession::Detection::Periods
  BUCKET = 5.minutes
  public_constant :BUCKET

  # A gap of this length or less does not end a period
  GAP = 15.minutes
  public_constant :GAP

  # `power`, `connected` and `gaps` are the curves of the day: [[Time,
  # value], ...], each Time the end of its bucket. `power` needs the buckets
  # with power alone, and `gaps` holds the buckets of the power without a
  # reading.
  def initialize(date, power:, connected: [], gaps: [])
    @day = Timeframe.new(date.iso8601)
    @power = power
    @connected = connected
    @gaps = gaps.to_set { it.first.to_i }
  end

  # [[from, to], ...]
  def call
    periods =
      power.each_with_object([]) do |(stamp, watt), result|
        next unless watt.positive?

        from = [stamp - BUCKET, day.beginning].max
        to = [stamp, day.ending].min
        last = result.last

        if last && bridged?(last[1], from)
          last[1] = to
        else
          result << [from, to]
        end
      end

    periods.map { |from, to| [reach_back(from), reach_forward(to)] }
  end

  private

  attr_reader :day, :power, :connected, :gaps

  # Whether a gap does not end the period: it is short, it has no data, or
  # it has a reading of the connection, and each of them reports a connected
  # car
  def bridged?(last_end, next_start)
    next_start - last_end <= GAP || without_data?(last_end, next_start) || connected_through?(last_end, next_start)
  end

  # Whether each bucket between the two periods has no reading
  def without_data?(last_end, next_start)
    ((last_end + BUCKET)..next_start).step(BUCKET).all? { gap?(it) }
  end

  def connected_through?(last_end, next_start)
    readings = connected.select { |time, _| time > last_end && time - BUCKET < next_start }
    readings.any? && readings.all? { it.last.positive? }
  end

  # The start of a period after buckets without a reading: the start of the
  # bucket with data before them, which holds the value before the gap
  def reach_back(from)
    stamp = from
    stamp -= BUCKET while gap?(stamp)
    stamp < from ? [stamp - BUCKET, day.beginning].max : from
  end

  # The end of a period before buckets without a reading: the end of the
  # bucket with data after them, which holds the value after the gap
  def reach_forward(to)
    stamp = to + BUCKET
    stamp += BUCKET while gap?(stamp)
    stamp > to + BUCKET ? [stamp, day.ending].min : to
  end

  def gap?(stamp) = gaps.include?(stamp.to_i)
end
