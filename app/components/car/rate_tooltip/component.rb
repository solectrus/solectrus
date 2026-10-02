# The tooltip of a rate tile of the car page. It gives the sum and the
# distance that the rate comes from, so the user can divide them and get the
# rate. It says that each day has a window of its own. With the distance of
# the card, it names the kilometers of the days without a rate.
class Car::RateTooltip::Component < ViewComponent::Base
  # The rates of the tiles: EUR/100 km and kWh/100 km
  RATES = %i[cost consumption].freeze
  private_constant :RATES

  def initialize(driving:, rate:, distance: nil)
    super()
    raise ArgumentError, "Unknown rate: #{rate}" if RATES.exclude?(rate)

    @driving = driving
    @rate = rate
    @distance = distance
  end

  attr_reader :driving, :distance

  def cost?
    @rate == :cost
  end

  def sum_label
    cost? ? t('sensors.car_driving_costs') : t('.energy')
  end

  def sum_value
    if cost?
      SensorValue::Component.new(driving.cost, :total_costs, precision: 2)
    else
      SensorValue::Component.new(driving.energy_wh, :wallbox_power, context: :total, scaling: :kilo, precision: 0)
    end
  end

  def rate_label
    cost? ? t('sensors.car_cost_per_100km_short') : t('sensors.car_consumption_per_100km_short')
  end

  # Rendered like the value of the tile
  def rate_value
    if cost?
      SensorValue::Component.new(driving.cost_per_100km, :total_costs, precision: 2)
    else
      SensorValue::Component.new(
        driving.consumption_per_100km * 1000,
        :wallbox_power,
        context: :total,
        scaling: :kilo,
        precision: 1,
      )
    end
  end

  # The distance of the days with this rate. A day without a cost has an
  # energy rate, but no cost rate.
  def rated_distance
    cost? ? driving.cost_distance : driving.distance
  end

  def margin_days
    Car::RateWindow::MARGIN_DAYS
  end
end
