# The savings of the driving against a combustion car (see Car::Comparison),
# as a bar below the card of the driving, with the costs of both cars in its
# tooltip. It opens the comparison page. A phone shows a link in the card in
# its place, because a bar above the timeline of a day looks like one of its
# lanes.
module Car::PeriodOverview::Driving::Savings
  # The comparison below the card, which opens the comparison page. Without
  # fuel prices, there is no page to open, and the bar is a gray track (see
  # #comparison_bar) whose tooltip says why.
  def comparison
    href = savings_path if report.savings?
    Car::Figure.new(sensor_name: nil, href:, value: comparison_bar, title: t('car_breakdown.savings'), **savings_tooltip)
  end

  # The savings as a link in the card, which a phone shows in the place of
  # the bar. It stays white like the card, because the green and the red of
  # the bar are too weak on the color of the card. Without a compared
  # distance, it names the savings alone, and the comparison page names the
  # gaps. Without a drive or without a comparison there is no link. Like the
  # lists of the cards, it opens the comparison in a sheet (see SheetPage).
  def savings_list
    return unless driven? && report.savings?

    Car::PeriodOverview::Card::Component::List.new(label: savings_link_label, href: savings_path, sheet_href: savings_path(sheet: 1), phone_only: true)
  end

  private

  def savings_link_label
    return t('.savings') unless amounts

    safe_join([icon(gain? ? 'piggy-bank' : 'circle-exclamation'), t(gain? ? '.saved' : '.extra', amount: amount(amounts.savings.abs))], ' ')
  end

  # The comparison of the cars as the comparison page shows it, nil without
  # a compared distance
  def amounts
    return @amounts if defined?(@amounts)

    @amounts = (Car::ComparisonAmounts.new(report.comparison) if report.savings? && report.comparison.ready?)
  end

  def savings_path(**)
    helpers.cars_savings_path(timeframe: (timeframe.to_param unless timeframe.all?), car: report.car&.id, **)
  end

  # The costs of both cars and the savings, for a screen reader
  def savings_label
    [[t('.ev'), amounts.car_cost], [t('.combustion'), amounts.combustion_cost], [t('.savings'), amounts.savings]].map { |name, value| "#{name} #{amount(value)}" }.join(', ')
  end

  # The comparison as a bar of the cost of the car and its savings, side by
  # side, so the whole bar is the cost of the combustion car. A loss puts the
  # extra cost beside the cost of the combustion car instead, so the whole
  # bar is the cost of the car. Without a compared distance, the bar is a
  # gray track, and the comparison page tells why. The cost of the car has
  # no label: the savings beside it say what the bar compares, and the
  # tooltip names both costs. The bar has the amounts only with the
  # comparison page, so it is always a link, whose press scales the labels.
  # The car has the green of PV, which is the green of the comparison page
  # in light mode, and in dark mode the darker green of the cards, because
  # the green of a dark text glares on a large area.
  def comparison_bar
    return Car::ShareBar::Component.new(segments: []) unless amounts

    base = gain? ? amounts.car_cost : amounts.combustion_cost
    base_part = Car::ShareBar::Component::Segment.new(value: [base, 0].max, css: gain? ? 'bg-car-pv-card' : Car::ComparisonFormat::COLORS[:combustion])
    Car::ShareBar::Component.new(segments: [base_part, savings_segment], label: savings_label, press: true)
  end

  def gain? = !amounts.savings.negative?

  # The savings or the loss, green or red, with its amount as its share of
  # the width beside the cost of a car
  def savings_segment
    savings = amount(amounts.savings.abs)
    Car::ShareBar::Component::Segment.new(
      value: amounts.savings.abs,
      css: ['px-3 text-base', gain? ? 'bg-signal-positive-soft text-signal-positive-strong' : 'bg-signal-negative-soft text-signal-negative-strong'],
      labels: [safe_join([icon(gain? ? 'piggy-bank' : 'circle-exclamation'), t(gain? ? '.saved' : '.extra', amount: savings)], ' '), savings],
    )
  end

  # The car and the combustion car, each in the color of its column on the
  # comparison page (see Car::ComparisonFormat::COLORS), and the savings
  # below them
  def savings_parts
    savings = amounts.savings
    [
      Car::Tooltip::Component::Part.new(label: t('.ev'), value: money(amounts.car_cost, precision: amounts.precision), color: 'var(--color-signal-positive)'),
      Car::Tooltip::Component::Part.new(label: t('.combustion'), value: money(amounts.combustion_cost, precision: amounts.precision), color: 'var(--color-combustion)'),
      Car::Tooltip::Component::Part.new(label: t('.savings'), value: helpers.tag.span(money(savings, precision: amounts.precision), class: savings_color_of(savings))),
    ]
  end

  def savings_tooltip
    amounts ? { parts: savings_parts, notes: [t('.savings_note')] } : { notes: [t(".no_savings.#{no_savings_reason}")] }
  end

  # Why the bar is a gray track: no drive, no comparison with fuel prices
  # for the car, or no compared distance, whose gaps the comparison page names
  def no_savings_reason
    if !driven? then :drive
    elsif !report.savings? then :comparison
    else :distance
    end
  end

  # An amount as plain text, for the bar and its label
  def amount(value) = Sensor::ValueFormatter.new(value, unit: Sensor::Registry[:total_costs].unit, precision: amounts.precision).to_s
end
