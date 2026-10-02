# The driving of a period: the distance with its average for each day, the
# driving cost and the two rates per 100 km it comes from. The tooltip of
# each value shows its calculation.
class Car::DrivingCard::Component < ViewComponent::Base
  include CarChartLink

  def initialize(balance:, timeframe:)
    super()
    @balance = balance
    @timeframe = timeframe
  end

  attr_reader :balance, :timeframe

  # The distance of the first selected car. Its chart shows each car in the
  # selection "all" (see Sensor::Chart::CarMileage).
  def distance_sensor_name
    Sensor::Cars.sensor_name(:car_mileage, balance.cars.first.id)
  end

  # The distance loads its chart, where the chart can draw the timeframe
  def distance_wrapper
    classes = 'block min-w-0 text-center'
    chart = chart_sensor_name(distance_sensor_name)
    return [:div, { class: classes }] unless chart

    [:a, { href: chart_link_url(chart), class: "click-animation focus:outline-none #{classes}", data: chart_link_data(chart) }]
  end

  def km_per_day
    distance = Sensor::ValueFormatter.new(balance.car_km_per_day, unit: :kilometer)
    "Ø #{distance}/#{t('sensors.car_km_per_day_unit')}"
  end

  # Rendered in kWh/100 km, like the value of the tile
  def consumption_value(kwh_per_km)
    SensorValue::Component.new(kwh_per_km&.*(1000), :wallbox_power, context: :total, scaling: :kilo, precision: 1)
  end

  # The driving cost is the distance times the cost per 100 km
  def driving_cost_tooltip
    return tooltip(notes: [t('.no_rate')]) unless balance.car_driving_costs

    tooltip(
      terms: [
        row(nil, t('sensors.car_distance_short'), distance_value(driving.cost_distance)),
        row('×', t('sensors.car_cost_per_100km_short'), cost_value(balance.car_cost_per_100km)),
      ],
      result: row('=', t('sensors.car_driving_costs'), SensorValue::Component.new(balance.car_driving_costs, :total_costs, sign: :negative)),
      notes: [unrated_note(driving.cost_distance)],
    )
  end

  # The cost per 100 km comes from the rates of the days. The tooltip says
  # how a day gets its rate, without a calculation: a calculation from the
  # driving cost would be circular, and no sum of the period gives the rate.
  def cost_rate_tooltip
    rate_tooltip(distance: driving.cost_distance, reason: '.cost_reason')
  end

  # The consumption comes from the rates of the days, like the cost per 100 km
  def consumption_rate_tooltip
    rate_tooltip(distance: driving.distance, reason: '.consumption_reason')
  end

  private

  delegate :driving, to: :balance

  # The distance holds the days with this rate: a day without a cost has an
  # energy rate, but no cost rate.
  def rate_tooltip(distance:, reason:)
    tooltip(notes: [t(reason, days: Car::DailyRates::MARGIN_DAYS), t('.charge_losses'), unrated_note(distance)])
  end

  # The kilometers of the period on days without a rate. The card shows them
  # in its distance, but the calculation leaves them out (see
  # Car::DailyRates). Rounded like the distance on the card, so a rest below
  # 0.5 km has no note.
  def unrated_note(rated_distance)
    unrated = (balance.car_distance.to_f - rated_distance).round
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
