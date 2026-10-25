class Sensor::Definitions::CarBatterySoc < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :percent, range: (0..100), category: :car

  # A car reports a change of its state, often only while it is online,
  # so the value holds until the next reading
  state

  # The level of a state of charge: critical up to 5%, low up to 20%. The
  # color here and the fill of the battery in Car::LiveCard follow it.
  def self.level(percent)
    if percent <= 5
      :critical
    elsif percent <= 20
      :low
    else
      :good
    end
  end

  color do |percent|
    case percent && Sensor::Definitions::CarBatterySoc.level(percent)
    when nil
      # Default for nil - neutral/no data
      {
        background: 'bg-sky-400 dark:bg-sky-600',
        text: 'text-sky-100 dark:text-sky-400',
        border: 'border-transparent',
      }
    when :critical
      {
        background: 'xl:tall:bg-red-200 dark:xl:tall:bg-red-900',
        text: 'text-signal-negative',
        border: 'border-red-200 dark:border-red-900',
      }
    when :low
      {
        background: 'xl:tall:bg-orange-200 dark:xl:tall:bg-amber-900',
        text: 'text-signal-warning',
        border: 'border-orange-200 dark:border-amber-900',
      }
    else
      {
        background: 'xl:tall:bg-emerald-200 dark:xl:tall:bg-emerald-900',
        text: 'text-signal-positive',
        border: 'border-emerald-200 dark:border-emerald-900',
      }
    end
  end

  # The state at the end of a day (`last`) gives the energy balance of the
  # battery (see Car::Driving). It means nothing across days, so no query
  # offers it.
  aggregations stored: %i[min max avg last], meta: %i[min max avg], computed: %i[min max avg]
  summary_version '2026-10-16'

  # Named like the home battery, which stands next to it on the power
  # balance, with the short name of the car: "Ladestand ZOE". Without a
  # given name, as for a guest, the one car in use is just the car.
  def display_name(_format = :long)
    car = Car.given_short_name_of(car_number)
    return I18n.t('sensors.car_battery_soc') if car.nil? && Car.sole_in_use&.id == car_number

    I18n.t('sensors.car_sensor.soc', car: car || Car.default_name(car_number))
  end

  # The power balance shows the chart of the one car in use next to the home
  # battery, as its badge does (see Balance::SocBadge::Component). Otherwise
  # the car page shows the chart of the role (see CarBatterySocChart).
  home_pages { Car.sole_in_use&.id == car_number ? [:balance] : [] }

  chart do |timeframe, **|
    Sensor::Chart::CarBatterySoc.new(timeframe:, cars: Car.configured.select { it.id == car_number })
  end

  requires_permission :car
end
