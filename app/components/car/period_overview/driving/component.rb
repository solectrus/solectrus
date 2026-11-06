# The driving of a period or a day as a card of the overview of the car page
# (see Car::PeriodOverview::Component): the distance, with the average
# distance of a day and on "all" the distance of each car in its tooltip.
# Below it the energy cost, the rates per 100 km and the link to the places.
# The tooltip of each rate has the window that the rates come from. A phone
# shows the links alone, and the tooltip of the distance has the figures.
# The comparison with a combustion car follows below the card (see
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

  # Each car with its distance and its whole share, rounded so the shares
  # add up to 100
  def car_parts
    shares = LargestRemainder.round(car_distances.values.map { it * 100 / distance })
    car_distances.zip(shares).map do |(car, km), percent|
      Car::Tooltip::Component::Part.new(label: car.display_name, value: render(Sensor::Value::Component.new(km, :car_distance)), color: car.display_color, percent:)
    end
  end

  # The distance with the distance of each car, the cost and the rates in its
  # tooltip. A phone shows the distance as the only number of the card, so
  # the tooltip has the figures of the cells (see #driving_parts) and their
  # notes (see #driving_notes).
  def distance_figure
    Car::Figure.new(sensor_name: :car_distance, value: render(distance_value), title: t('car_breakdown.driving'), parts: [*car_parts, *driving_parts], notes: driving_notes)
  end

  # The figures of the tooltip of the distance, in a group each: the
  # distance with its average of a day, which a day has not, the cost with
  # the cost per 100 km, and the consumption per 100 km
  def driving_parts
    part = Car::Tooltip::Component::Part
    per_day = Sensor::ValueFormatter.new(report.km_per_day, unit: Sensor::Registry[:car_distance].unit).to_s if report.km_per_day
    [
      part.new(label: t('sensors.car_distance'), value: render(distance_value), group: :distance),
      (part.new(label: t('.per_day'), value: per_day, group: :distance) if per_day),
      part.new(label: t('sensors.car_driving_costs'), value: cost_figure.value, group: :cost),
      part.new(label: t('.per_100km'), value: cost_rate_figure.value, group: :cost),
      part.new(label: t('sensors.car_consumption_rate'), value: consumption_figure.value, group: :consumption),
    ].compact
  end

  # One note says how the rates and the cost come about, the others what is
  # missing
  def driving_notes
    [(t('.summary', days: Car::Driving::MARGIN_DAYS) if note), *cost_notes, *energy_gaps].uniq
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

  # The cells of the card: the cost, the rates per 100 km, the savings on a
  # phone (see #savings_list) and the link to the places, if any
  def cells = [*rate_cells, savings_list, places_list].compact

  # The cost, which the card names, and the rates per 100 km. Each rate has
  # a cell of its own, so the tooltip of the cost leaves out the cost per 100
  # km, and keeps what is missing.
  def rate_cells
    cell = Car::PeriodOverview::Card::Component::Cell
    [
      cell.new(figure: cost_figure),
      cell.new(figure: consumption_figure, label: t('.per_100km')),
      cell.new(figure: cost_rate_figure, label: t('.per_100km')),
    ]
  end

  private

  def driven? = distance&.positive?

  def consumption_figure
    @consumption_figure ||= rate_figure(:car_consumption_rate, driving.consumption_per_100km&.then { consumption_value(it) }, energy_notes)
  end

  def cost_rate_figure
    @cost_rate_figure ||= rate_figure(:car_cost_rate, driving.cost_per_100km&.then { cost_rate_value(it) }, cost_notes)
  end

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
    @cost_figure ||= begin
      cost = render(cost_value(driving.cost)) if driving.cost_rated?
      notes = cost ? [t('.cost_basis'), (t('.cost_difference') if charging_cost_differs?(cost))] : []
      Car::Figure.new(sensor_name: :car_driving_costs, title: t('.cost_title'), value: cost || '–', notes: [*notes.compact, *cost_notes])
    end
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

  def energy_notes = driven? && driving.consumption_per_100km ? [t('.consumption_losses'), *energy_gaps] : energy_gaps

  # What the consumption per 100 km lacks: the whole rate, or the kilometers
  # on days without a rate
  def energy_gaps
    return [] unless driven?
    return [t('.no_rate')] unless driving.consumption_per_100km

    [unrated_note(driving.distance)].compact
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
