# The charges in a curve of the state of charge of a car, for the energy of
# an offsite session in the day chart (see ChargingSession::OffsiteProfile)
# and for the proposals of offsite sessions (see
# ChargingSession::OffsiteDetection).
#
# A step goes from one reading to the next. The readings of the same value
# join into one pause, and the steps up to a fall or up to a pause longer
# than MAX_PAUSE are one run, the steps of one charge.
class ChargingSession::SocRuns
  # A charge with a slow rise reports the same state of charge for a while,
  # but not for longer than this
  MAX_PAUSE = 1.hour
  private_constant :MAX_PAUSE

  # `curve` is [[Time, value], ...] in the order of time
  def initialize(curve)
    @curve = curve
  end

  # [[[from, to, rise], ...], ...]: the steps of each run
  def call
    steps.chunk_while { |step, next_step| charging?(step) && charging?(next_step) }.to_a
  end

  private

  attr_reader :curve

  # [[from, to, rise], ...] between two readings, with the readings of the
  # same value joined into one pause
  def steps
    curve
      .each_cons(2)
      .map { |(time, value), (next_time, next_value)| [time, next_time, next_value - value] }
      .chunk_while { |step, next_step| step.last.zero? && next_step.last.zero? }
      .map { |run| [run.first.first, run.last.second, run.sum(&:last)] }
  end

  def charging?((from, to, rise))
    rise.positive? || (rise.zero? && to - from <= MAX_PAUSE)
  end
end
