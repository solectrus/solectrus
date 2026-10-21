# The driving of a period: the distance with its average for each day, the
# driving cost with its rate per 100 km, the consumption per 100 km and the
# average maximum range. The tooltips of the cost and the consumption explain
# how they come about.
class Car::DrivingCard::Component < ViewComponent::Base
  include Car::ChartLink

  def initialize(report:)
    super()
    @report = report
  end

  attr_reader :report

  delegate :timeframe, :cars, :distance, :driving, :driving_cost, to: :report

  # The chart of the distance shows each selected car
  def distance_sensor_name = :car_distance

  # The distance loads its chart, where the chart can draw the timeframe. The
  # distance per day stands below the distance, but beside it on a phone,
  # which shows one card and has no room for one more line. The toggle of a
  # phone loads the chart of the card from here.
  def distance_wrapper
    chart_wrapper(
      chart_sensor_name(distance_sensor_name),
      class: 'block max-sm:flex max-sm:items-baseline max-sm:justify-center max-sm:gap-3 min-w-0 text-center',
      link_class: 'click-animation focus:outline-none',
      data: { car_cards_target: 'chart', car_card: 'driving' },
    )
  end

  def km_per_day
    distance = Sensor::ValueFormatter.new(report.km_per_day, unit: :kilometer)
    "Ø #{distance}/#{t('sensors.car_km_per_day_unit')}"
  end

  delegate :cost_per_100km, :consumption_per_100km, to: :driving

  # The consumption in kWh/100 km, like the value of the tile. Its unit is
  # Wh, so the value takes a factor of 1000.
  CONSUMPTION_FORMAT = { context: :total, scaling: :kilo, precision: 1 }.freeze
  private_constant :CONSUMPTION_FORMAT

  def consumption_value(kwh_per_100km)
    Sensor::Value::Component.new(kwh_per_100km&.*(1000), :wallbox_power, **CONSUMPTION_FORMAT)
  end

  # The average maximum range belongs to one car, so "all" of several cars
  # has neither value nor chart
  def max_range_chart = chart_sensor_name('car_max_range')

  # The maximum range needs the range and the state of charge of a car. The
  # row stays for "all" of several cars, so the layout does not change with
  # the selection.
  def max_range?
    cars.any? { it.sensor?(:car_max_range) }
  end

  # The visits at the places in the timeframe, at the foot of the card like
  # the sessions of the charging card. Only a car with a location has visits,
  # and the visits are whole days. A guest sees the counts too, like the
  # sessions, but the map asks for the login.
  def visits?
    !timeframe.now? && !timeframe.hours? && cars.any?(&:located?)
  end

  # The places of the visits that overlap the timeframe. The badge opens
  # their map, and the map leads on to the list of the visits.
  def places_count = report.visit_counts[:places]

  def places_path = helpers.cars_place_map_path(**page_params)

  # The timeframe and the selected car of the list and the map. The whole
  # time has no timeframe in their address.
  def page_params = { timeframe: (timeframe.to_param unless timeframe.all?), car: report.car&.id }

  # A short phone has no room for the label above the count, so they stand
  # side by side
  BADGE_CLASSES = [
    Car::Card::Component::BADGE,
    'bg-slate-200 dark:bg-slate-700/60',
    'max-sm:tiny:flex-row max-sm:tiny:justify-between max-sm:tiny:gap-2 max-sm:tiny:px-3 max-sm:tiny:py-1.5',
  ].join(' ').freeze
  private_constant :BADGE_CLASSES

  def badge_classes = BADGE_CLASSES

  # The bars of the rates and the maximum range in the span of their periods
  # (see Car::Spans), nil without a span. The ends are formatted like the
  # value of the row and open their period with the chart of the row. A low
  # rate is good, a low range is not.
  def cost_rate_bar
    span_bar(cost_per_100km, spans&.cost_per_100km, 'car_cost_rate', better: :lower) { formatted(it, :total_costs, precision: 2) }
  end

  def consumption_bar
    span_bar(consumption_per_100km, spans&.consumption_per_100km, 'car_consumption_rate', better: :lower) do
      formatted(it * 1000, :wallbox_power, **CONSUMPTION_FORMAT)
    end
  end

  def max_range_bar
    span_bar(report.max_range, spans&.max_range, 'car_max_range', better: :higher) { formatted(it, :car_max_range) }
  end

  # The driving cost is the distance times the cost per 100 km. With an
  # energy rate and without a cost, a session around the trip has no price.
  def driving_cost_tooltip
    return tooltip(notes: [t(driving.rated? ? '.no_price' : '.no_rate')]) unless driving_cost

    tooltip(
      terms: [
        row(nil, t('sensors.car_distance_short'), distance_value(driving.cost_distance)),
        row('×', t('sensors.car_cost_per_100km_short'), cost_value(cost_per_100km)),
      ],
      result: row('=', t('sensors.car_driving_costs'), Sensor::Value::Component.new(driving_cost, :total_costs)),
      notes: [unrated_note(driving.cost_distance)],
    )
  end

  # The cost per 100 km comes from the rates of the days. The tooltip says
  # how a day gets its rate, without a calculation: a calculation from the
  # driving cost would be circular, and no sum of the period gives the rate.
  def cost_rate_tooltip
    tooltip(notes: rate_notes(distance: driving.cost_distance, reason: '.cost_reason')) if cost_per_100km
  end

  # The maximum range is the range at a full battery. A car of "all" has
  # none (see #max_range?).
  def max_range_tooltip
    tooltip(notes: [t('.range_reason'), t('.range_estimate')]) if report.car
  end

  # The consumption comes from the rates of the days, like the cost per
  # 100 km
  def consumption_rate_tooltip
    tooltip(notes: rate_notes(distance: driving.distance, reason: '.consumption_reason')) if consumption_per_100km
  end

  private

  delegate :spans, to: :report

  # The block formats a value of the span
  def span_bar(value, span, chart, better:, &format)
    return unless value && span

    Car::SpanBar::Component.new(value:, span:, better:, shown: timeframe, format:, url: ->(period) { period_url(chart, period) })
  end

  def formatted(value, sensor_name, **) = Sensor::ValueFormatter.new(value, unit: Sensor::Registry[sensor_name].unit, **).to_s

  # The car page of another period of the same kind. A chart that cannot
  # draw the period gives way to the distance, like the card does.
  def period_url(chart, period)
    helpers.cars_home_path(sensor_name: chart_sensor_name(chart) || distance_sensor_name, timeframe: period, **helpers.selection_params)
  end

  # How a day gets its rate. The distance holds the days with this rate: a
  # day without a cost has an energy rate, but no cost rate.
  def rate_notes(distance:, reason:)
    [t(reason, days: Car::Driving::MARGIN_DAYS), t('.charge_losses'), unrated_note(distance)]
  end

  # The kilometers of the period on days without a rate. The card shows them
  # in its distance, but the calculation leaves them out (see Car::Driving).
  # Rounded like the distance on the card, so a rest below 0.5 km has no
  # note.
  def unrated_note(rated_distance)
    unrated = (distance.to_f - rated_distance).round
    t('.unrated', distance: Sensor::ValueFormatter.new(unrated, unit: :kilometer).to_s) if unrated.positive?
  end

  def tooltip(notes:, terms: [], result: nil)
    Car::CalculationTooltip::Component.new(terms:, result:, notes: notes.compact)
  end

  def row(operator, label, value)
    Car::CalculationTooltip::Component::Row.new(operator:, label:, value:)
  end

  def distance_value(distance)
    Sensor::Value::Component.new(distance, distance_sensor_name)
  end

  def cost_value(cost)
    Sensor::Value::Component.new(cost, :total_costs, precision: 2)
  end
end
