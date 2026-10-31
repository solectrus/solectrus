# The start and the end of each period at the readings of the wallbox (see
# ChargingSession::Detection).
#
# A period is a run of 5-minute buckets with power (see Periods), so it
# starts at the start of its first bucket and ends at the end of its last
# one, up to 5 minutes before and after the power. A session starts with the
# first reading with power in the first bucket. It ends with the first
# reading without power after the last reading with power in the last
# bucket, which is also the end of a collector that writes a change alone.
# Without such a reading, the end stays at the end of the bucket, because
# nothing tells that the power stopped earlier. So an edge moves only
# within its bucket.
#
# The detection cuts a charge over midnight into a session for each day. A
# period that starts at midnight with power before it continues the charge
# of the day before, so it keeps the start of the day. A charge that starts
# after midnight, like with the tariff of the night, starts at its reading.
#
# The buckets stay the rules of the detection: the periods, their energy
# and the choice of the car read them, and only the stored times move.
class ChargingSession::Detection::Edges
  BUCKET = ChargingSession::Detection::Periods::BUCKET
  private_constant :BUCKET

  # `periods` are the [from, to] of the periods, on the edges of the buckets
  def initialize(periods)
    @periods = periods
  end

  # { [from, to] => [start, end] } of each period
  def call
    return {} if @periods.empty? || !Sensor::Config.configured?(:wallbox_power)

    rows = Sensor::Query::Helpers::Influx::FluxProgram.query(flux, class_name: self.class.name, sensors: [:wallbox_power])
    readings = rows.group_by { it['edge'] }.transform_values { |edge_rows| edge_rows.map { [Time.iso8601(it['_time']), it['_value'].to_f] }.sort_by(&:first) }

    @periods.each_with_index.to_h do |(from, to), index|
      start = continued?(readings["p#{index}"]) ? from : start_at(readings["s#{index}"], from)
      [[from, to], [start, end_at(readings["e#{index}"], to)]]
    end
  end

  private

  # The first reading with power, which the program selects already
  def start_at(readings, from) = readings&.first&.first || from

  # Whether the last reading before midnight has power
  def continued?(readings) = readings.present? && readings.last.last.positive?

  def midnight?(time) = time == time.in_time_zone.beginning_of_day

  # The first reading without power after the last one with power. A period
  # that reaches across a gap of the collector ends in the bucket after the
  # gap (see Periods), whose readings can all be without power: the last
  # one with power lies before the gap.
  def end_at(readings, to)
    return to unless readings

    last = readings.rindex { it.last.positive? }
    readings[last ? last + 1 : 0]&.first || to
  end

  # The start needs its first reading with power alone. The end needs each
  # reading of its bucket, because a reading without power follows the last
  # one with power. A period at midnight needs the last reading before it.
  def flux
    program = Sensor::Query::Helpers::Influx::FluxProgram
    streams =
      @periods.each_with_index.flat_map do |(from, to), index|
        [
          stream("s#{index}", from, from + BUCKET, "|> filter(fn: (r) => float(v: r._value) > 0.0)\n  |> first()"),
          stream("e#{index}", to - BUCKET, to),
          (stream("p#{index}", from - BUCKET, from, '|> last()') if midnight?(from)),
        ].compact
      end

    "#{program.source(Sensor::Query::Helpers::Influx::SensorFilter.predicate([:wallbox_power]))}#{streams.join}#{program.union(streams.map { it[/\A(\w+) =/, 1] })}"
  end

  def stream(name, start, stop, selection = nil)
    <<~FLUX
      #{name} = source(#{Sensor::Query::Helpers::Influx::FluxProgram.range_args(start, stop)})
        #{selection}
        |> set(key: "edge", value: "#{name}")
        |> keep(columns: ["_time", "_value", "edge"])
    FLUX
  end
end
