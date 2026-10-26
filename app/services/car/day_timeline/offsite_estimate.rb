# When an offsite session without an end charged, for the timeline of a day
# (see Car::DayTimeline). Such a session has no time of its own, so the
# readings of its car give the signs, in this order:
#
# 1. The state of charge rises: the charge follows the rise.
# 2. The car is plugged in: the charge lies in the time plugged in.
# 3. Otherwise: the charge lies in the whole time.
#
# A car does not charge while it drives or while it charges in another
# session, so these times give no sign. A rise that reaches into another
# session belongs to that session, also with its part outside, because the
# readings come seldom. A change of NOISE is no rise.
#
# The signs can give a small part far from the charge, like a rise of the
# state of charge at another charger. So the charge lies in the run of signs
# with the most weight.
#
# The readings are those of the rest of the timeline, each at the end of its
# bucket, and a reading holds until the next one. So the estimate fits the
# line of the state of charge and the time plugged in.
class Car::DayTimeline::OffsiteEstimate
  NOISE = Car::DayTimeline::Drives::NOISE
  private_constant :NOISE

  # `from` and `to` are the time in which the session can have charged.
  # `soc` and `plug` are the [[Time, value], ...] of the state of charge and
  # of the plug, the state at the start of the day first. `drives` and
  # `charges` are the [from, to] of the drives and of the other charging
  # sessions of the car.
  def initialize(from:, to:, soc: [], plug: [], drives: [], charges: [])
    @from = from
    @to = to
    @soc = soc
    @plug = plug
    @drives = drives
    @charges = charges
  end

  # [from, to] of the charge, or nil without a time in which the car can
  # have charged
  def call
    return if @to <= @from

    weights = soc_weights || plug_weights || free_weights
    heaviest_run(weights) if weights
  end

  private

  # [from, to] of the pieces one after the other with a weight, the run with
  # the most weight
  def heaviest_run(weights)
    run = pieces.zip(weights).chunk_while { |(_, before), (_, after)| before.positive? && after.positive? }.select { it.first.last.positive? }.max_by { |part| part.sum(&:last) }
    [run.first.first.first, run.last.first.last]
  end

  # [[from, to], ...] of the time between each two times at which a sign
  # changes
  def pieces
    @pieces ||= [@from, @to, *[@soc, @plug].flat_map { it.map(&:first) }, *[@drives, @charges].flatten]
                .grep(@from..@to)
                .uniq
                .sort
                .each_cons(2)
                .to_a
  end

  # The rise of the state of charge in each piece, or nil without a rise
  def soc_weights
    positive(pieces.map { |from, to| busy?(from, to) ? 0.0 : rises.sum { |rise_from, rise_to, rise| rise * overlap(from, to, rise_from, rise_to) / (rise_to - rise_from) } })
  end

  # [[from, to, rise], ...] of the charges in the readings (see
  # ChargingSession::SocRuns), without the steps in another session. A rise
  # spreads evenly over its charge, also over a step of the same value in
  # it, like in a slow charge, but not over such a step at its start or at
  # its end.
  def rises
    @rises ||=
      ChargingSession::SocRuns.new(@soc).call
      .select { it.sum(&:last) > NOISE }
      .flat_map { |run| run.reject { |from, to, _| charging?(from, to) }.slice_when { |before, after| before.second != after.first }.to_a }
      .filter_map { rise_of(it) }
  end

  def rise_of(steps)
    steps = steps.drop_while { it.last.zero? }.reverse.drop_while { it.last.zero? }.reverse
    rise = steps.sum(&:last)
    [steps.first.first, steps.last.second, rise] if rise.positive?
  end

  # The time of each piece in which the car is plugged in, or nil without
  # such a piece. Without readings of the plug, it gives no sign.
  def plug_weights
    return if @plug.empty?

    positive(pieces.map { |from, to| plugged?(from) && !busy?(from, to) ? to - from : 0.0 })
  end

  def free_weights = positive(pieces.map { |from, to| busy?(from, to) ? 0.0 : to - from })

  def positive(weights) = (weights if weights.sum.positive?)

  def plugged?(time) = @plug.rfind { |reading_time, _| reading_time <= time }&.last.to_f.positive?

  def busy?(from, to) = charging?(from, to) || @drives.any? { |drive_from, drive_to| overlap(from, to, drive_from, drive_to).positive? }

  def charging?(from, to) = @charges.any? { |charge_from, charge_to| overlap(from, to, charge_from, charge_to).positive? }

  def overlap(from, to, other_from, other_to) = [[to, other_to].min - [from, other_from].max, 0].max
end
