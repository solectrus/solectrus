# The driving of a period or a day as a card of the overview of the car page
# (see Car::PeriodOverview::Component): the distance, with the average
# distance of a day and on "all" the distance of each car in its tooltip.
# Below it the energy cost, the rates per 100 km and the link to the places.
# The tooltip of each rate has the window that the rates come from. The
# comparison with a combustion car follows below the card (see
# Car::PeriodOverview::Driving::Savings).
class Car::PeriodOverview::Driving::Component < ViewComponent::Base
  include Car::ComparisonFormat
  include Car::PeriodOverview::Driving::Savings

  def initialize(report:)
    super()
    @report = report
  end

  attr_reader :report

  delegate :timeframe, :cars, :distance, :driving, to: :report

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
      Car::Tooltip::Component::Part.new(label: car.display_name, value: render(Sensor::Value::Component.new(km, :car_distance)), color: car.display_color, percent:)
    end
  end

  # The average distance of a day, nil for a day
  def per_day_part
    return unless report.km_per_day

    Car::Tooltip::Component::Part.new(label: t('.per_day'), value: Sensor::ValueFormatter.new(report.km_per_day, unit: Sensor::Registry[:car_distance].unit).to_s)
  end

  # The distance with its average of a day and the distance of each car in
  # its tooltip
  def distance_figure
    Car::Figure.new(sensor_name: :car_distance, value: render(distance_value), title: t('sensors.car_distance'), parts: distance_parts)
  end

  # A period without a drive says so alone
  def empty = (Car::PeriodOverview::Card::Component::Empty.new(icon: 'car', text: t('.none')) unless driven?)

  # The list of the places, which only a car with a location has, and a
  # period without a drive leaves out
  def places_path(**)
    helpers.cars_visited_places_path(timeframe: timeframe.to_param, car: report.car&.id, **) if driven? && cars.any?(&:located?)
  end

  # The link to the list of the places
  def places_list
    places_path&.then { Car::PeriodOverview::Card::Component::List.new(label: t('car_breakdown.places'), href: it, sheet_href: places_path(sheet: 1)) }
  end

  # The cells of the card: the cost, which the card names, the rates per 100
  # km and the link to the places, if any. Each rate has a cell of its own,
  # so the tooltip of the cost leaves out the cost per 100 km, and keeps what
  # is missing.
  def cells
    cell = Car::PeriodOverview::Card::Component::Cell
    consumption = driving.consumption_per_100km&.then { consumption_value(it) }
    cost_rate = driving.cost_per_100km&.then { cost_rate_value(it) }
    [
      cell.new(figure: cost_figure),
      cell.new(figure: rate_figure(:car_consumption_rate, consumption, energy_notes), label: t('.per_100km')),
      cell.new(figure: rate_figure(:car_cost_rate, cost_rate, cost_notes), label: t('.per_100km')),
      places_list,
    ].compact
  end

  private

  def driven? = distance&.positive?

  # A rate per 100 km as a figure of the card, which loads its chart. Its
  # tooltip has the window of the rates as its first note, before what only
  # this rate means.
  def rate_figure(sensor_name, value, notes)
    Car::Figure.new(sensor_name:, title: t("sensors.#{sensor_name}"), value: value ? render(value) : '–', notes: [note, *notes].compact)
  end

  # The window of the rates. The figures of a day read like its own
  # numbers, but the rates come from the days around it. Without a rate, its
  # tooltip tells what is missing.
  def note
    t('.window', days: Car::Driving::MARGIN_DAYS) if driving.cost_per_100km || driving.consumption_per_100km
  end

  # The energy cost loads the chart of the driving cost. Without a cost rate,
  # the cost of the driven kilometers is unknown. Its tooltip keeps what is
  # missing, because the cost per 100 km has a cell of its own. With a cost,
  # it says how the cost comes about, and why it differs from the cost of
  # charging, if the two show different numbers.
  def cost_figure
    cost = render(cost_value(driving.cost)) if driving.cost_rated?
    notes = cost ? [t('.cost_basis'), (t('.cost_difference') if charging_cost_differs?(cost))] : []
    Car::Figure.new(sensor_name: :car_driving_costs, title: t('.cost_title'), value: cost || '–', notes: [*notes.compact, *cost_notes])
  end

  # Whether the card of the charging shows another cost than `cost`, the
  # rendered driving cost
  def charging_cost_differs?(cost)
    sessions = report.sessions
    sessions.cost? && render(cost_value(sessions.cost)) != cost
  end

  def cost_value(cost) = Sensor::Value::Component.new(cost, :total_costs)

  # The notes of a rate say what only this rate means. Without a rate they
  # tell what is missing. With an energy rate but without a cost rate, a
  # session around the trip has no price. Without a drive, nothing is missing.
  def cost_notes
    return [] unless driven?
    return [t(driving.rated? ? '.no_price' : '.no_rate')] unless driving.cost_per_100km

    [unrated_note(driving.cost_distance)].compact
  end

  def energy_notes
    return [] unless driven?
    return [t('.no_rate')] unless driving.consumption_per_100km

    [t('.consumption_losses'), unrated_note(driving.distance)].compact
  end

  # A rate per 100 km with its unit: the energy in kWh, the cost in money
  def consumption_value(kwh) = Sensor::Value::Component.new(kwh * 1000, :wallbox_power, context: :total, scaling: :kilo, precision: 1)

  def cost_rate_value(cost) = Sensor::Value::Component.new(cost, :total_costs, precision: 2)

  def kilometers(value) = Sensor::ValueFormatter.new(value.round, unit: Sensor::Registry[:car_distance].unit).to_s

  # The kilometers on days without a rate, which the distance holds but the
  # rate leaves out (see Car::Driving). Rounded like the distance, so a rest
  # below 0.5 km has no note.
  def unrated_note(rated_distance)
    unrated = (distance.to_f - rated_distance).round
    t('.unrated', distance: kilometers(unrated)) if unrated.positive?
  end
end
