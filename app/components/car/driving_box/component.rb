# The driving of a period in the overview of the car page (see
# Car::OverviewBox::Component): the distance, with the average distance of a
# day and on "all" the distance of each car in its tooltip. Beside it, the
# energy used and the energy cost. The tooltip of each has its rate per 100
# km with a bar of its place between the periods of its kind (see
# Car::Spans), and the info icon of the title the window that the rates come
# from. With a comparison with a combustion car, the savings stand below
# them, and open the comparison.
class Car::DrivingBox::Component < ViewComponent::Base
  include Car::ComparisonFormat

  def initialize(report:)
    super()
    @report = report
  end

  attr_reader :report

  delegate :timeframe, :cars, :distance, :driving, :spans, to: :report

  # A period without a drive has 0 km
  def distance_value = Sensor::Value::Component.new(distance || 0, :car_distance)

  # The distance of each car with a distance, the cars of "all" only
  def car_distances
    @car_distances ||= cars.many? ? report.distances.select { |_, km| km&.positive? } : {}
  end

  # The average distance of a day, then each car with its distance and its
  # whole share, rounded so the shares add up to 100
  def distance_parts
    [per_day_part, *car_parts].compact
  end

  def car_parts
    shares = LargestRemainder.round(car_distances.values.map { it * 100 / distance })
    car_distances.zip(shares).map do |(car, km), percent|
      Car::OverviewBox::Component::Part.new(label: car.display_name, value: render(Sensor::Value::Component.new(km, :car_distance)), color: car.display_color, percent:)
    end
  end

  # The average distance of a day, nil for a day
  def per_day_part
    return unless report.km_per_day

    Car::OverviewBox::Component::Part.new(label: t('.per_day'), value: Sensor::ValueFormatter.new(report.km_per_day, unit: Sensor::Registry[:car_distance].unit).to_s)
  end

  # The distance with its average of a day and the distance of each car in
  # its tooltip, the energy used and the energy cost. The cost comes last,
  # like in the charging (see Car::ChargingBox::Component). The rates per 100
  # km stand in the tooltips.
  def figures
    [
      Car::OverviewBox::Component::Figure.new(sensor_name: :car_distance, value: render(distance_value), title: t('sensors.car_distance'), parts: distance_parts),
      energy_figure,
      cost_figure,
    ]
  end

  # The bar of the savings against a combustion car, or nil without a
  # comparison. The page knows the place of the bar before the figures load
  # (see Car::Report#savings?), so the bar stays also without a compared
  # distance. It is an empty track then, and the comparison tells why.
  def bar
    return unless Car::Section.bar?(:driving, report)

    Car::OverviewBox::Component::Figure.new(sensor_name: nil, href: savings_path, value: savings_bar, title: t('car_breakdown.savings'), **savings_tooltip)
  end

  # A period without a drive says so in the place of the figures
  def empty
    Car::OverviewBox::Component::Empty.new(icon: 'car', text: t('.none')) unless driven?
  end

  # The window that the rates come from, in the info icon of the column. The
  # figures of a day read like its own numbers, but the rates come from the
  # days around it. Without a rate, its tooltip tells what is missing.
  def note
    t('.window', days: Car::Driving::MARGIN_DAYS) if driving.cost_per_100km || driving.consumption_per_100km
  end

  # The list of the places, which only a car with a location has, and a
  # period without a drive leaves out
  def places_path(**)
    helpers.cars_visited_places_path(timeframe: timeframe.to_param, car: report.car&.id, **) if driven? && cars.any?(&:located?)
  end

  private

  def driven? = distance&.positive?

  # The comparison of the cars as the comparison page shows it, nil without
  # a compared distance
  def amounts
    return @amounts if defined?(@amounts)

    @amounts = (Car::ComparisonAmounts.new(report.comparison) if report.comparison.ready?)
  end

  def savings_path
    helpers.cars_savings_path(timeframe: (timeframe.to_param unless timeframe.all?), car: report.car&.id)
  end

  # The savings as an amount, in the place and the height of a bar, so the
  # boxes of both columns end on one line. It shows no ratio: the amount
  # matters, and the tooltip names the costs of each column. A loss is red.
  def savings_bar
    return Car::ShareBar::Component.new(segments: []) unless amounts

    Car::ShareBar::Component.new(
      segments: [savings_segment],
      label: [[t('.ev'), amounts.car_cost], [t('.combustion'), amounts.combustion_cost], [t('.savings'), amounts.savings]].map { |name, value| "#{name} #{amount(value)}" }.join(', '),
    )
  end

  def savings_segment
    savings = amount(amounts.savings.abs)
    gain = !amounts.savings.negative?
    Car::ShareBar::Component::Segment.new(
      value: 1,
      css: ['px-3 text-base', gain ? 'bg-signal-positive-soft text-signal-positive-strong' : 'bg-signal-negative-soft text-signal-negative-strong'],
      labels: [safe_join([icon(gain ? 'piggy-bank' : 'circle-exclamation'), t(gain ? '.saved' : '.extra', amount: savings)], ' '), savings],
    )
  end

  # The car and the combustion car, each in the color of its column on the
  # comparison page (see Car::ComparisonFormat::COLORS), and the savings
  # below them
  def savings_parts
    savings = amounts.savings
    [
      Car::OverviewBox::Component::Part.new(label: t('.ev'), value: money(amounts.car_cost, precision: amounts.precision), color: 'var(--color-signal-positive)'),
      Car::OverviewBox::Component::Part.new(label: t('.combustion'), value: money(amounts.combustion_cost, precision: amounts.precision), color: 'var(--color-combustion)'),
      Car::OverviewBox::Component::Part.new(label: t('.savings'), value: helpers.tag.span(money(savings, precision: amounts.precision), class: savings_color_of(savings))),
    ]
  end

  def savings_tooltip
    amounts ? { parts: savings_parts, notes: [t('.savings_note')] } : {}
  end

  # An amount as plain text, for the bar and its label
  def amount(value) = Sensor::ValueFormatter.new(value, unit: Sensor::Registry[:total_costs].unit, precision: amounts.precision).to_s

  # The energy cost loads the chart of the driving cost. Without a cost rate,
  # the cost of the driven kilometers is unknown. The figures of the driving
  # have no caption, so the three of them fit in one line. Their tooltips
  # name them.
  def cost_figure
    cost = Sensor::Value::Component.new(driving.cost, :total_costs) if driving.cost_rated?
    Car::OverviewBox::Component::Figure.new(
      sensor_name: :car_driving_costs,
      title: t('sensors.car_driving_costs'),
      description: t('.cost_description'),
      value: cost ? render(cost) : '–',
      **cost_tooltip,
    )
  end

  # The energy used loads its chart. Without an energy rate, the energy of
  # the driven kilometers is unknown.
  def energy_figure
    energy = Sensor::Value::Component.new(driving.energy_wh, :wallbox_power, context: :total, scaling: :kilo, precision: driving.energy_wh >= 100_000 ? 0 : 1) if driving.rated?
    Car::OverviewBox::Component::Figure.new(
      sensor_name: :car_driving_energy,
      title: t('sensors.car_driving_energy'),
      description: t('.energy_description'),
      value: energy ? render(energy) : '–',
      **energy_tooltip,
    )
  end

  # The tooltip of a figure has its rate per 100 km (see #rate_tooltip), and
  # what only this figure means. The window of both rates stands in the info
  # icon alone (see #note). Without a rate it tells what is missing. With an
  # energy rate but without a cost rate, a session around the trip has no
  # price. Without a drive, nothing is missing.
  def cost_tooltip
    return {} unless driven?
    return { notes: [t(driving.rated? ? '.no_price' : '.no_rate')] } unless driving.cost_per_100km

    rate_tooltip(:car_cost_rate, driving.cost_per_100km, spans&.cost_per_100km, precision: 2, notes: [unrated_note(driving.cost_distance)]) do
      Sensor::Value::Component.new(it, :total_costs, precision: 2)
    end
  end

  def energy_tooltip
    return {} unless driven?
    return { notes: [t('.no_rate')] } unless driving.consumption_per_100km

    rate_tooltip(:car_consumption_rate, driving.consumption_per_100km, spans&.consumption_per_100km, precision: 1, notes: [t('.consumption_losses'), unrated_note(driving.distance)]) do
      Sensor::Value::Component.new(it * 1000, :wallbox_power, context: :total, scaling: :kilo, precision: 1)
    end
  end

  # The rate with the bar of its place among the periods. A low rate is
  # good. The ends of the bar have the numbers alone, because the rate above
  # them has the unit. `precision` is the number of decimals of these ends.
  # The block gives a rate with its unit.
  def rate_tooltip(sensor_name, value, span, precision:, notes:, &)
    part = Car::OverviewBox::Component::Part.new(label: t("sensors.#{sensor_name}"), value: render(yield(value)))
    bar = Car::SpanBar::Component.new(value:, span:, better: :lower, precision:, rows: span_rows(span, sensor_name, &)) if span
    { parts: [part], bar:, notes: notes.compact }
  end

  # The lowest and the highest rate for a sheet, as rows with a link to their
  # period, like in the insights
  def span_rows(span, sensor_name)
    { minimum: [span.min, span.min_timeframe], maximum: [span.max, span.max_timeframe] }.map do |key, (rate, period)|
      Insights::Row::Component.new(label: t(".#{key}"), note: Car::SpanBar::Component.period(period), url: period_path(period, sensor_name)).with_content(render(yield(rate)))
    end
  end

  # The car page of a period with the chart of the rate. A day has its
  # timeline in place of the charts.
  def period_path(period, sensor_name)
    helpers.cars_home_path(sensor_name: (sensor_name if Car::Section.charts?(period)), timeframe: period.to_s, **helpers.selection_params)
  end

  def kilometers(value) = Sensor::ValueFormatter.new(value.round, unit: Sensor::Registry[:car_distance].unit).to_s

  # The kilometers on days without a rate, which the distance holds but the
  # rate leaves out (see Car::Driving). Rounded like the distance, so a rest
  # below 0.5 km has no note.
  def unrated_note(rated_distance)
    unrated = (distance.to_f - rated_distance).round
    t('.unrated', distance: kilometers(unrated)) if unrated.positive?
  end
end
