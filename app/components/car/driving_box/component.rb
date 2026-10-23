# The driving of a period in the overview of the car page (see
# Car::OverviewBox::Component): the distance, a ring of the share of each car
# with the average distance of a day in the center, and the distance of each
# car. Below, the cost and the consumption per 100 km, each with a bar of its
# place between the periods of its kind (see Car::Spans).
class Car::DrivingBox::Component < ViewComponent::Base
  def initialize(report:)
    super()
    @report = report
  end

  attr_reader :report

  delegate :timeframe, :cars, :distance, :driving, :spans, to: :report

  # A period without a drive has 0 km
  def distance_value = Sensor::Value::Component.new(distance || 0, :car_distance)

  def value_label = "#{t('sensors.car_distance')} #{Sensor::ValueFormatter.new(distance || 0, unit: Sensor::Registry[:car_distance].unit)}"

  # The distance of each car with a distance, the cars of "all" only. One car
  # has the ring in the color of the chart of the distance.
  def car_distances
    @car_distances ||= cars.many? ? report.distances.select { |_, km| km&.positive? } : {}
  end

  def segments
    if car_distances.any?
      car_distances.map { |car, km| Car::OverviewBox::Component::Segment.new(percent: km * 100 / distance, color: car.display_color) }
    elsif distance&.positive?
      [Car::OverviewBox::Component::Segment.new(percent: 100, color: "var(#{Sensor::Registry[:car_distance].color_variable})")]
    else
      []
    end
  end

  # Each car with its distance and its whole share, rounded so the shares
  # add up to 100
  def parts
    shares = LargestRemainder.round(car_distances.values.map { it * 100 / distance })
    car_distances.zip(shares).map do |(car, km), percent|
      Car::OverviewBox::Component::Part.new(label: car.display_name, value: render(Sensor::Value::Component.new(km, :car_distance)), color: car.display_color, percent:)
    end
  end

  def center = report.km_per_day && Sensor::ValueFormatter.new(report.km_per_day, unit: Sensor::Registry[:car_distance].unit).to_s

  def center_label = (t('car_breakdown.per_day') if center)

  def head
    Car::OverviewBox::Component::Head.new(sensor_name: :car_distance, label: value_label, value: render(distance_value), segments:, center:, center_label:, parts:)
  end

  # The cost and the consumption per 100 km. A low rate is good.
  def figures = rates.map { |label, figure| figure.with(label: t("car_breakdown.#{label}")) }

  # The tiles of a phone: the distance with its average of a day, and the
  # two rates with their short names
  def tiles
    [
      Car::OverviewBox::Component::Figure.new(sensor_name: :car_distance, label: t('sensors.car_distance_short'), value: render(distance_value), note: (t('car_breakdown.per_day_note', distance: center) if center)),
      *rates.map { |label, figure| figure.with(label: t("car_breakdown.#{label}_short")) },
    ]
  end

  # The list of the places, which only a car with a location has, and a
  # period without a drive leaves out
  def places_path
    helpers.cars_visited_places_path(timeframe: timeframe.to_param, car: report.car&.id) if driven? && cars.any?(&:located?)
  end

  private

  def driven? = distance&.positive?

  # A new bar for each place, because a component renders once
  def rates
    [
      rate(:cost_rate, :car_cost_rate, driving.cost_per_100km, spans&.cost_per_100km, **cost_rate_tooltip) do
        Sensor::ValueFormatter.new(it, unit: Sensor::Registry[:total_costs].unit, precision: 2).to_s
      end,
      rate(:consumption_rate, :car_consumption_rate, driving.consumption_per_100km, spans&.consumption_per_100km, **consumption_rate_tooltip) do
        Sensor::ValueFormatter.new(it * 1000, unit: Sensor::Registry[:wallbox_power].unit, context: :total, scaling: :kilo, precision: 1).to_s
      end,
    ]
  end

  # A rate with the bar of its place among the periods. A day has no chart
  # of a rate, so its figure loads nothing.
  def rate(label, sensor_name, value, span, parts: [], notes: [])
    bar = Car::SpanBar::Component.new(value:, span:, better: :lower) if value && span
    [label, Car::OverviewBox::Component::Figure.new(sensor_name:, label: nil, value: value ? yield(value) : '–', bar:, parts:, notes:)]
  end

  # The tooltip of a rate has the amount that it divides by the distance
  # beside it, and what only this rate means. Without a rate it tells what
  # is missing. With an energy rate but without a cost rate, a session
  # around the trip has no price. Without a drive, nothing is missing.
  def cost_rate_tooltip
    return {} unless driven?
    return { notes: [t(driving.rated? ? '.no_price' : '.no_rate')] } unless driving.cost_per_100km

    {
      parts: [rate_part(t('sensors.car_driving_costs'), currency(driving.cost))],
      notes: [t('.cost_reason', days: Car::Driving::MARGIN_DAYS), unrated_note(driving.cost_distance)].compact,
    }
  end

  def consumption_rate_tooltip
    return {} unless driven?
    return { notes: [t('.no_rate')] } unless driving.consumption_per_100km

    energy = Sensor::ValueFormatter.new(driving.energy_wh, unit: Sensor::Registry[:wallbox_power].unit, context: :total, scaling: :kilo, precision: 0).to_s
    {
      parts: [rate_part(t('.energy'), energy)],
      notes: [t('.consumption_reason', days: Car::Driving::MARGIN_DAYS), t('.consumption_losses'), unrated_note(driving.distance)].compact,
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
