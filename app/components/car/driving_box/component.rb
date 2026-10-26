# The driving of a period in the overview of the car page (see
# Car::OverviewBox::Component): the distance with the average distance of a
# day, and on "all" a bar of the share of each car. Beside it, the cost and
# the consumption per 100 km, each with a bar of its place between the
# periods of its kind (see Car::Spans), and below them the window that they
# come from.
class Car::DrivingBox::Component < ViewComponent::Base
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

  # The color of a drive in the timeline of a day. A period without a drive
  # has no color, like a period without charging.
  def swatch
    return [Car::OverviewBox::Component::NEUTRAL] unless driven?

    [Car::OverviewBox::Component::Segment.new(percent: 100, color: Car::DayTimeline::Component::DRIVE_COLOR)]
  end

  # The share of each car in its color. One car has no bar, because its
  # share is the whole.
  def segments
    car_distances.map { |car, km| Car::OverviewBox::Component::Segment.new(percent: km * 100 / distance, color: car.display_color) }
  end

  # Each car with its distance and its whole share, rounded so the shares
  # add up to 100
  def parts
    shares = LargestRemainder.round(car_distances.values.map { it * 100 / distance })
    car_distances.zip(shares).map do |(car, km), percent|
      Car::OverviewBox::Component::Part.new(label: car.display_name, value: render(Sensor::Value::Component.new(km, :car_distance)), color: car.display_color, percent:)
    end
  end

  # The average distance of a day, nil for a day
  def per_day = report.km_per_day && Sensor::ValueFormatter.new(report.km_per_day, unit: Sensor::Registry[:car_distance].unit).to_s

  # The distance with its average of a day below it, and the two rates. On a
  # phone, their unit tells them apart, each "per 100 km". A low rate is
  # good.
  def figures
    [
      Car::OverviewBox::Component::Figure.new(sensor_name: :car_distance, label: per_day ? t('car_breakdown.per_day_note', distance: per_day) : t('car_breakdown.driven'), value: render(distance_value), segments:, parts:),
      *rates,
    ]
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

  # The rates with the precision of their unit
  def rates
    [
      rate(:cost_rate, :car_cost_rate, driving.cost_per_100km, spans&.cost_per_100km, precision: 2, **cost_rate_tooltip) do |value|
        Sensor::Value::Component.new(value, :total_costs, precision: 2)
      end,
      rate(:consumption_rate, :car_consumption_rate, driving.consumption_per_100km, spans&.consumption_per_100km, precision: 1, **consumption_rate_tooltip) do |value|
        Sensor::Value::Component.new(value * 1000, :wallbox_power, context: :total, scaling: :kilo, precision: 1)
      end,
    ]
  end

  # A rate with the bar of its place among the periods. A day has no chart
  # of a rate, so its figure loads nothing. The ends of the bar have the
  # numbers of the span alone, because the value above them has the unit.
  # `precision` is the number of decimals of these ends, and `tooltip` has
  # the parts and the notes of the figure.
  def rate(label, sensor_name, value, span, precision:, **tooltip)
    bar = Car::SpanBar::Component.new(value:, span:, better: :lower, precision:) if value && span
    Car::OverviewBox::Component::Figure.new(
      sensor_name:,
      label: t('car_breakdown.per_100km'),
      wide_label: t("car_breakdown.#{label}"),
      value: value ? render(yield(value)) : '–',
      bar:,
      **tooltip,
    )
  end

  # The tooltip of a rate has the amount that it divides by the distance
  # beside it, and what only this rate means. The window of both rates stands
  # in the info icon alone (see #note). Without a rate it tells what is
  # missing. With an energy rate but without a cost rate, a session
  # around the trip has no price. Without a drive, nothing is missing.
  def cost_rate_tooltip
    return {} unless driven?
    return { notes: [t(driving.rated? ? '.no_price' : '.no_rate')] } unless driving.cost_per_100km

    {
      parts: [rate_part(t('sensors.car_driving_costs'), currency(driving.cost))],
      notes: [unrated_note(driving.cost_distance)].compact,
    }
  end

  def consumption_rate_tooltip
    return {} unless driven?
    return { notes: [t('.no_rate')] } unless driving.consumption_per_100km

    energy = Sensor::ValueFormatter.new(driving.energy_wh, unit: Sensor::Registry[:wallbox_power].unit, context: :total, scaling: :kilo, precision: 0).to_s
    {
      parts: [rate_part(t('.energy'), energy)],
      notes: [t('.consumption_losses'), unrated_note(driving.distance)].compact,
    }
  end

  def rate_part(label, value) = Car::OverviewBox::Component::Part.new(label:, value:, color: nil, percent: nil)

  # Cents below 100, where they still count, whole amounts above
  def currency(value) = Sensor::ValueFormatter.new(value, unit: Sensor::Registry[:total_costs].unit, precision: value >= 100 ? 0 : 2).to_s

  def kilometers(value) = Sensor::ValueFormatter.new(value.round, unit: Sensor::Registry[:car_distance].unit).to_s

  # The kilometers on days without a rate, which the distance holds but the
  # rate leaves out (see Car::Driving). Rounded like the distance, so a rest
  # below 0.5 km has no note.
  def unrated_note(rated_distance)
    unrated = (distance.to_f - rated_distance).round
    t('.unrated', distance: kilometers(unrated)) if unrated.positive?
  end
end
