# The driving of a period in the overview of the car page (see
# Car::OverviewBox::Component): the distance with the average distance of a
# day, and on "all" a bar of the share of each car. Beside it, the driving
# cost and the energy used. The tooltip of each has its rate per 100 km with
# a bar of its place between the periods of its kind (see Car::Spans), and
# the info icon of the title the window that the rates come from.
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

  # The distance with its average of a day below it, the energy used and the
  # driving cost. The cost comes last, like in the charging (see
  # Car::ChargingBox::Component). The rates per 100 km stand in the tooltips.
  def figures
    [
      Car::OverviewBox::Component::Figure.new(sensor_name: :car_distance, label: per_day ? t('car_breakdown.per_day_note', distance: per_day) : t('car_breakdown.driven'), value: render(distance_value), segments:, parts:),
      energy_figure,
      cost_figure,
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

  # The driving cost loads its chart. Without a cost rate, the cost of the
  # driven kilometers is unknown.
  def cost_figure
    cost = Sensor::Value::Component.new(driving.cost, :total_costs) if driving.cost_rated?
    Car::OverviewBox::Component::Figure.new(
      sensor_name: :car_driving_costs,
      label: t('car_breakdown.cost'),
      wide_label: t('sensors.car_driving_costs'),
      value: cost ? render(cost) : '–',
      **cost_tooltip,
    )
  end

  # The energy used has no chart of its own, so it loads the chart of the
  # consumption per 100 km
  def energy_figure
    energy = Sensor::Value::Component.new(driving.energy_wh, :wallbox_power, context: :total, scaling: :kilo, precision: driving.energy_wh >= 100_000 ? 0 : 1) if driving.rated?
    Car::OverviewBox::Component::Figure.new(
      sensor_name: :car_consumption_rate,
      label: t('car_breakdown.used'),
      wide_label: t('.energy'),
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
    part = Car::OverviewBox::Component::Part.new(label: t("sensors.#{sensor_name}"), value: render(yield(value)), color: nil, percent: nil)
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
