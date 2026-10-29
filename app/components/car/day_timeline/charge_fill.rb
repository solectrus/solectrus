# The fill of the bar of a charge on the timeline of a day (see
# Car::DayTimeline::Component and Car::TimelineBar::Bar). A charge at the
# wallbox draws the curve of its power over its time as areas, PV at the
# bottom, the grid above it, and the power without a split on top (see
# Car::DayTimeline::ChargePower). All charges of the timeline share one
# scale, the highest power of the day, so a slow charge stays low beside a
# fast one. Any other charge keeps the shares of its sources.
#
# A pause in which the car stayed plugged in is grey, so the energy of the
# session stands once. A gap in which the wallbox sent no data is grey with
# dots.
module Car::DayTimeline::ChargeFill
  LAYERS = { pv: :pv, grid: :grid, unsplit: :wallbox }.freeze
  private_constant :LAYERS

  def charge_fill(charge)
    {
      segments: Car::ChargingSource.of(charge.session).map { |key, weight| [Car::ChargingSource[key].color, weight] },
      areas: charge_areas(charge),
      pauses: charge.pauses.map { part_of(it, charge.span) },
      gaps: charge.gaps.map { part_of(it, charge.span) },
    }
  end

  # [[CSS color, SVG path], ...] in a box of 1000 x 100 over the bar of the
  # charge, a layer without power left out. Empty without a curve, so the
  # bar keeps the shares of its sources.
  def charge_areas(charge)
    positions = positions(charge)
    return [] unless positions

    lower = Array.new(positions.size, 0.0)
    LAYERS.filter_map do |layer, source|
      upper = lower.zip(charge.power).map { |below, point| below + point.public_send(layer) }
      area = (area_path(positions, lower, upper) if upper != lower)
      lower = upper
      [Car::ChargingSource[source].color, area] if area
    end
  end

  private

  # A pause or a gap as [left, width] in percent of the time of its charge
  def part_of((part_from, part_to), (from, to))
    [part_from - from, part_to - part_from].map { (it * 100.0 / (to - from)).round(3) }
  end

  # The highest power of all charges on the timeline
  def peak_power
    @peak_power ||= lanes.flat_map(&:charges).flat_map(&:power).map(&:total).max || 0
  end

  # The place of each point in the box, from 0 at the start of the charge to
  # 1000 at its end. Nil without a curve to draw.
  def positions(charge)
    from, to = charge.span
    return if charge.power.empty? || peak_power.zero? || to <= from

    charge.power.map { ((it.time - from) * 1000.0 / (to - from)).round(2) }
  end

  # The area between two lines, along the upper one and back along the
  # lower one
  def area_path(positions, lower, upper)
    points = [*positions.zip(upper), *positions.zip(lower).reverse].map { |x, value| "#{x} #{(100 - (value * 100.0 / peak_power)).round(2)}" }
    "M#{points.join(' L')} Z"
  end
end
