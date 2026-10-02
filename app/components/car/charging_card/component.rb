# The charging of a period: the charged energy, a column of segments for its
# sources like the source column of the power balance, the charging cost, the
# average maximum range and the number of guest and offsite sessions. The
# tooltip of a segment gives its share and its cost. Without the power
# splitter the column has one segment. The energy and the cost come from the
# charging sessions of the selected cars (see Car::Balance).
class Car::ChargingCard::Component < ViewComponent::Base
  include CarChartLink
  include CarRoundedCosts

  # The sources from the top of the column to its bottom, like the power
  # balance with the grid on top and PV at the bottom: color, icon, label
  SOURCES = {
    offsite: %w[bg-sensor-offsite charging-station car_breakdown.offsite],
    grid: %w[bg-sensor-grid bolt car_breakdown.home_grid],
    pv: %w[bg-sensor-pv sun car_breakdown.home_pv],
  }.freeze
  private_constant :SOURCES

  # A segment below this share would be a hairline
  MIN_PERCENT = 0.3
  private_constant :MIN_PERCENT

  def initialize(balance:, timeframe:)
    super()
    @balance = balance
    @timeframe = timeframe
  end

  attr_reader :balance, :timeframe

  def split?
    energy_parts.present? && total_wh.positive?
  end

  def total_wh
    @total_wh ||= balance.charged_wh.to_f
  end

  # The average maximum range belongs to one car, so "all" has none
  def max_range_sensor_name
    Sensor::Cars.sensor_name(:car_max_range, balance.car.id) if balance.car
  end

  # The segments of the column, with their energy (Wh), their share in
  # percent and their cost. Without a split, one segment holds all energy.
  # Without charged energy, the column stays empty.
  def segments
    return [] unless total_wh.positive?
    return [unsplit_segment] unless split?

    whole_percents = rounded_percents
    SOURCES.filter_map do |source, (color_class, icon, label_key)|
      energy = energy_parts[source]
      percent = energy * 100 / total_wh
      next if percent < MIN_PERCENT

      {
        color_class:,
        icon:,
        label: t(label_key),
        energy:,
        percent:,
        whole_percent: whole_percents[source],
        cost: costs.parts[source],
      }
    end
  end

  def cost_value(cost, **)
    SensorValue::Component.new(cost, :total_costs, sign: :negative, **(split? ? costs.options : {}), **)
  end

  def energy_value(energy_wh, **)
    SensorValue::Component.new(energy_wh, :wallbox_power, context: :total, scaling: :kilo, precision:, **)
  end

  # The wallbox, the offsite and the guest sessions, each with the list it
  # opens. Without a wallbox there is no wallbox or guest session, and their
  # badges are hidden, not zero.
  def sessions
    {
      wallbox: ({ kind: 'wallbox', car: car_param } if wallbox?),
      offsite: { kind: 'offsite', car: car_param },
      guest: ({ kind: 'wallbox', car: ChargingSessionList::CarFilter::GUEST } if wallbox?),
    }.compact
  end

  delegate :session_totals, to: :balance

  # The cost of a guest session is a loss of its own, not a charging cost of
  # the car, so it has no sign (like in Car::ChargingCostTooltip)
  def session_cost(kind, cost, **)
    SensorValue::Component.new(cost, :total_costs, sign: (:negative unless kind == :guest), **)
  end

  # Three badges side by side are narrow, so there the label stands above the
  # count. A guest session belongs to no car, so its badge is an outline.
  def badge_classes(kind)
    [
      'click-animation flex items-center justify-between sm:flex-col sm:justify-center gap-1 sm:gap-0 min-w-0',
      'rounded-lg px-2 md:px-3 py-1 md:py-1.5',
      'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400',
      kind == :guest ? 'ring-1 ring-inset ring-slate-300 dark:ring-slate-600' : 'bg-slate-200 dark:bg-slate-700/60',
    ]
  end

  def wallbox?
    Sensor::Config.exists?(:wallbox_power)
  end

  private

  # The list shows the sessions of the selected car, or of all cars
  def car_param = balance.car&.id

  def unsplit_segment
    {
      color_class: 'bg-sensor-wallbox',
      icon: 'plug',
      label: t('sensors.car_charged_short'),
      energy: total_wh,
      percent: 100,
      whole_percent: 100,
      cost: balance.charging_costs,
    }
  end

  # Whole percentages for the tooltips that add up to 100 (see LargestRemainder)
  def rounded_percents
    percents = energy_parts.transform_values { it * 100 / total_wh }
    percents.keys.zip(LargestRemainder.round(percents.values)).to_h
  end

  delegate :charge_split, to: :balance

  # Rounded so the costs of the segments add up to the charging cost, like
  # in Car::ChargingCostTooltip
  def costs
    @costs ||= rounded_costs(charge_split.cost)
  end

  def energy_parts
    @energy_parts ||= charge_split.energy
  end

  # From 100 kWh on, a decimal adds nothing
  def precision
    total_wh >= 100_000 ? 0 : 1
  end
end
