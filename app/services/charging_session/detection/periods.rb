# The periods of a day in which the wallbox charged, found on the 5-minute
# means of its curves. A period is a continuous time with wallbox_power > 0.
# A gap of GAP or less does not end it, because load management and PV
# surplus control make such gaps.
#
# wallbox_car_connected bridges a longer gap, but it never moves an end: the
# first bucket with power is the start, and the last is the end. Otherwise a
# charge before the sensor reports the connection loses its energy, and the
# balance of the day breaks. The period keeps the parts with power on both
# sides of such a gap, so the timeline of the car page shows the pause (see
# Car::DayTimeline).
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

  # A period with the parts in it where the wallbox had power, [[from, to],
  # ...]. A connected car joins two parts over a longer pause, so a period
  # can have more than one part.
  Period = Data.define(:parts) do
    def from = parts.first.first

    def to = parts.last.last
  end
  public_constant :Period

  # The periods of a day from the curves of the build (see
  # ChargingSession::Curves)
  def self.of(curves, date)
    new(
      date,
      power: curves.wallbox.dig(date, :wallbox_power) || [],
      connected: curves.wallbox.dig(date, :wallbox_car_connected) || [],
      gaps: curves.wallbox_gaps.dig(date, :wallbox_power) || [],
    )
  end

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

  # The periods of the day
  def call
    parts
      .slice_when { |before, after| !connected_through?(before.last, after.first) }
      .map { |run| Period.new(parts: reach(run)) }
  end

  private

  attr_reader :day, :power, :connected, :gaps

  # [[from, to], ...] of the times with power, joined over a short gap or a
  # gap without data
  def parts
    power.each_with_object([]) do |(stamp, watt), result|
      next unless watt.positive?

      from = [stamp - BUCKET, day.beginning].max
      to = [stamp, day.ending].min
      last = result.last

      if last && joined?(last[1], from)
        last[1] = to
      else
        result << [from, to]
      end
    end
  end

  # Whether a gap does not end the part: it is short, or it has no data
  def joined?(last_end, next_start)
    next_start - last_end <= GAP || without_data?(last_end, next_start)
  end

  # Whether each bucket between the two periods has no reading
  def without_data?(last_end, next_start)
    ((last_end + BUCKET)..next_start).step(BUCKET).all? { gap?(it) }
  end

  def connected_through?(last_end, next_start)
    readings = connected.select { |time, _| time > last_end && time - BUCKET < next_start }
    readings.any? && readings.all? { it.last.positive? }
  end

  # The parts reach across the buckets without a reading at their ends. Two
  # parts can reach to the same bucket with data, so a part ends where the
  # next one starts at the latest.
  def reach(run)
    reached = run.map { |from, to| [reach_back(from), reach_forward(to)] }
    reached.each_cons(2) { |before, after| before[1] = [before.last, after.first].min }
    reached
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
