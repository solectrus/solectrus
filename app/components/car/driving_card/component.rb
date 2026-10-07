# The driving of a period: the distance with its average for each day, the
# driving cost with its rate per 100 km, the consumption per 100 km and the
# average maximum range. The tooltips of the cost and the consumption explain
# how they come about.
class Car::DrivingCard::Component < ViewComponent::Base
  include CarChartLink

  def initialize(report:)
    super()
    @report = report
  end

  attr_reader :report

  delegate :timeframe, :cars, :distance, :driving, :driving_cost, to: :report

  # The chart of the distance shows each selected car
  def distance_sensor_name = :car_distance

  # The distance loads its chart, where the chart can draw the timeframe
  def distance_wrapper
    chart_wrapper(chart_sensor_name(distance_sensor_name), class: 'block min-w-0 text-center', link_class: 'click-animation focus:outline-none')
  end

  def km_per_day
    distance = Sensor::ValueFormatter.new(report.km_per_day, unit: :kilometer)
    "Ø #{distance}/#{t('sensors.car_km_per_day_unit')}"
  end

  delegate :cost_per_100km, :consumption_per_100km, to: :driving

  # Rendered in kWh/100 km, like the value of the tile
  def consumption_value(kwh_per_100km)
    SensorValue::Component.new(kwh_per_100km&.*(1000), :wallbox_power, context: :total, scaling: :kilo, precision: 1)
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

  # The row of the driving cost: the sum and the cost per 100 km side by
  # side under one title. A phone shows it as a tile in the full width.
  def cost_row_classes = "#{Car::Card::Component::ROW} max-sm:col-span-2"

  # The tag and the options of a number in the row of the driving cost. It
  # loads its own chart and has its own tooltip. A tap on a link opens the
  # chart, so its tooltip needs a long press (like Car::StatRow::Component).
  def cost_cell(sensor_name)
    chart = chart_sensor_name(sensor_name)
    chart_wrapper(
      chart,
      class: 'flex flex-col items-center min-w-0 px-1',
      link_class: 'click-animation focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400',
      data: {
        controller: 'tooltip',
        tooltip_placement_value: 'left',
        tooltip_force_tap_to_close_value: false,
        tooltip_touch_value: chart ? 'long' : 'true',
      },
    )
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
      result: row('=', t('sensors.car_driving_costs'), SensorValue::Component.new(driving_cost, :total_costs)),
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
    tooltip(notes: [t('.range_reason')]) if report.car
  end

  # The consumption comes from the rates of the days, like the cost per
  # 100 km
  def consumption_rate_tooltip
    tooltip(notes: rate_notes(distance: driving.distance, reason: '.consumption_reason')) if consumption_per_100km
  end

  private

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
    SensorValue::Component.new(distance, distance_sensor_name)
  end

  def cost_value(cost)
    SensorValue::Component.new(cost, :total_costs, precision: 2)
  end
end
