# The line of the state of charge as the timeline of a day draws it (see
# Car::DayTimeline::Component). A car reports whole percent, so a charge or
# a drive is a stair of small steps (see Car::DayTimeline::SocLine). The
# drawn line runs through the middle of each step instead, as long as the
# next step follows within SLOPE. A longer hold stays flat, like a parked
# car. The tooltips keep the readings.
module Car::DayTimeline::SocCurve
  # The longest hold between two steps that the line runs across. A slow
  # charge gains 1 % in about 15 minutes.
  SLOPE = 30.minutes
  private_constant :SLOPE

  # The pieces of the drawn line, like those of Car::DayTimeline::SocLine
  def soc_curve(lane)
    line = lane.soc_line
    corners = line.each_with_index.flat_map { |segment, index| soc_corners(line, segment, index) }
    corners << [line.last.to, line.last.to_value, true]

    corners.each_cons(2).filter_map do |(from, from_value, known), (to, to_value, _)|
      Car::DayTimeline::SocLine::Segment.new(from:, to:, from_value:, to_value:, known:) unless from == to && from_value == to_value
    end
  end

  private

  # [[time, value, known], ...] where the drawn line turns, each with whether
  # the line from there to the next corner is known. A step turns in its
  # middle, and a short hold between two steps has no corner.
  def soc_corners(line, segment, index)
    return [[segment.from, segment.from_value, false]] unless segment.known
    return [[segment.from, (segment.from_value + segment.to_value) / 2.0, true]] if soc_step?(segment)
    return [] if index.positive? && segment.to - segment.from <= SLOPE && soc_step?(line[index - 1]) && soc_step?(line[index + 1])

    [[segment.from, segment.from_value, true], [segment.to, segment.to_value, true]]
  end

  def soc_step?(segment) = segment&.known && segment.from == segment.to
end
