# The line of the state of charge of a car on a day (see Car::DayTimeline),
# from its readings.
#
# A car reports at a pace of its own. Some cars report every few minutes,
# others only now and then, like after a drive or a charge. Between two close
# readings, the line holds the first value and steps at the second, like the
# chart of the state of charge. Between two readings more than MAX_GAP apart,
# a step at the second reading would come too late: a car that charged at
# noon and reported in the evening would rise in the evening. So the change
# follows what explains it: a rise follows the charging sessions in the gap,
# and a fall follows the drives. Without such an event, nothing tells when the
# value changed, so the line is a slope from one reading to the next. Both
# are estimates, which the line draws dashed.
class Car::DayTimeline::SocLine
  # A piece of the line, from one value to the next. `known` is false where
  # the readings leave open when the value changed, so the piece is an
  # estimate.
  Segment = Data.define(:from, :to, :from_value, :to_value, :known)
  public_constant :Segment

  # Like the drives (see Car::DayTimeline::Drives)
  MAX_GAP = Car::DayTimeline::Drives::MAX_GAP
  private_constant :MAX_GAP

  # A change of the noise of the reading steps at its reading
  NOISE = Car::DayTimeline::Drives::NOISE
  private_constant :NOISE

  # `points` are the [[Time, percent], ...] of the line: the value at the
  # start of the day and each reading after it. The line holds the last value
  # until `ends_at`. `drives` are the [from, to, distance] of the drives of
  # the car, a drive without a start with its end twice. `charges` are the
  # [from, to] of its charging sessions.
  def initialize(points, ends_at:, drives: [], charges: [])
    @points = points.sort_by(&:first)
    @ends_at = ends_at
    @drives = drives
    @charges = charges
  end

  def call
    segments = @points.each_cons(2).flat_map { |(from, from_value), (to, to_value)| between(from, from_value, to, to_value) }
    last_time, last_value = @points.last
    segments << flat(last_time, @ends_at, last_value) if last_time && @ends_at > last_time
    joined(segments)
  end

  private

  # A car that reports every few minutes with the same value holds it in one
  # piece, not in a piece for each reading
  def joined(segments)
    segments
      .chunk_while { |before, after| flat?(before) && flat?(after) && before.to_value == after.from_value && before.to == after.from }
      .map { |run| run.one? ? run.first : run.first.with(to: run.last.to) }
  end

  def flat?(segment) = segment.known && segment.from_value == segment.to_value

  def between(from, from_value, to, to_value)
    return [flat(from, to, from_value)] if from_value == to_value
    return step(from, from_value, to, to_value, at: to) if (to_value - from_value).abs <= NOISE
    return step(from, from_value, to, to_value, at: step_time(from, to, rise: to_value > from_value)) if to - from <= MAX_GAP

    spans = event_spans(from, to, rise: to_value > from_value)
    return [Segment.new(from:, to:, from_value:, to_value:, known: false)] if spans.empty?

    along(spans, from, to, from_value, to_value).select { it.to > it.from || it.from_value != it.to_value }
  end

  # The line holds the first value and steps to the second at the time
  def step(from, from_value, to, to_value, at:)
    [flat(from, at, from_value), Segment.new(from: at, to: at, from_value:, to_value:, known: true), (flat(at, to, to_value) if at < to)].compact
  end

  # A change between two close readings steps at the second one. A car
  # reports late, so where an event that explains the change ended between
  # them, like a charge before a rise, the step lies at its end.
  def step_time(from, to, rise:)
    (rise ? @charges : @drives).filter_map { |start, stop| stop if stop > start && stop > from && stop < to }.max || to
  end

  # [[from, to, weight], ...] of the events in the gap that explain the
  # change, cut to the gap and to each other. The reading at the start of
  # the gap already holds an event that ends there.
  def event_spans(from, to, rise:)
    cursor = from

    (rise ? @charges : @drives)
      .select { |start, stop| in_gap?(start, stop, from, to) }
      .sort_by { |start, stop| [start, stop] }
      .map do |start, stop, distance|
        cut = [start, cursor].max
        cursor = [stop, to].min.clamp(cut..)
        [cut, cursor, weight(distance, stop - start, cursor - cut)]
      end
  end

  # The weight of the part of an event in the gap: of a drive its part of the
  # distance, of a charge its time
  def weight(distance, length, time)
    return time unless distance

    length.positive? ? distance * time / length : distance
  end

  def in_gap?(start, stop, from, to)
    start == stop ? start > from && start <= to : start < to && stop > from
  end

  # The change follows the events, each by its share of their weight, and
  # holds between them, like in the pause of a charge. Events without a
  # weight share the change evenly. The readings tell neither the times nor
  # the values from the first event to the last, so these pieces are
  # estimates.
  def along(spans, from, to, from_value, to_value)
    total = spans.sum(&:last)
    cursor = from
    value = from_value

    segments =
      spans.each_with_index.flat_map do |(start, stop, weight), index|
        share = total.positive? ? weight.to_f / total : 1.0 / spans.size
        next_value = index == spans.size - 1 ? to_value : value + ((to_value - from_value) * share)
        pieces = [flat(cursor, start, value, known: index.zero?), Segment.new(from: start, to: stop, from_value: value, to_value: next_value, known: false)]
        cursor = stop
        value = next_value
        pieces
      end

    [*segments, flat(cursor, to, to_value)]
  end

  def flat(from, to, value, known: true) = Segment.new(from:, to:, from_value: value, to_value: value, known:)
end
