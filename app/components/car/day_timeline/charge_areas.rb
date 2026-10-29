# The curve of a charge at the wallbox inside its bar on the timeline of a
# day (see Car::DayTimeline::Component): its power over its time as areas,
# PV at the bottom, the grid above it, and the power without a split on top
# (see Car::DayTimeline::ChargePower). All charges of the timeline share one
# scale, the highest power of the day, so a slow charge stays low beside a
# fast one.
module Car::DayTimeline::ChargeAreas
  LAYERS = { pv: :pv, grid: :grid, unsplit: :wallbox }.freeze
  private_constant :LAYERS

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
