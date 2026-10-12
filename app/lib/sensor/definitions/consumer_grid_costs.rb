# What a single consumer costs when it draws from the grid: its own energy at
# the rate per kWh.
#
# The base fee of the tariff is no part of it: the fee does not grow with the
# consumption, so a heat pump or a wallbox does not raise it. Only the house
# carries the fee (see Sensor::Definitions::HouseCostsGrid), which keeps the
# per-consumer costs summing up to grid_costs.
#
# An includer names its power sensor, and nothing else: the whole definition -
# dependencies, prices, and both calculations - follows from that name and is
# the same for every consumer.
module Sensor::Definitions::ConsumerGridCosts
  # The sensor that holds the part of this consumer's power which came from the
  # grid - must be implemented by the includer.
  def power_sensor
    # simplecov:disable
    raise NotImplementedError, 'Definition must implement #power_sensor'
    # simplecov:enable
  end

  def dependencies(**)
    super + [power_sensor]
  end

  # What the sensor cannot exist without, for Sensor::Config#exists? to prune an
  # unconfigured consumer by (see Sensor::Definitions::Base#static_dependencies).
  # It holds no Proc, so the recursive check is safe.
  def static_dependencies
    super + [power_sensor]
  end

  def required_prices
    [:electricity]
  end

  def sql_calculation
    with_base_fee_sql("#{power_sensor}_sum * pb_money_per_kwh / 1000.0")
  end

  # The fee itself, where the includer carries it, is added by
  # Sensor::Definitions::FinanceBase#with_base_fee.
  def calculate_with_prices(prices:, **values)
    electricity_price = prices[:electricity]
    power = values[power_sensor]
    return unless electricity_price && power

    power * electricity_price / 1000.0
  end
end
