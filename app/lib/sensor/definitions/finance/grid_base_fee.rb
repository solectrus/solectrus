# The fixed monthly amount the supplier charges for the grid connection, spread
# over the days it covers.
#
# A sensor of its own, rather than a number recomputed beside grid_costs: it is
# part of grid_costs, and only a value from the very same query splits that
# number without drifting from it.
class Sensor::Definitions::GridBaseFee < Sensor::Definitions::FinanceBase
  value

  # The fee buys the grid connection, so it is reported where the grid meter is.
  depends_on :grid_import_power

  aggregations stored: false, computed: [:sum], meta: [:sum]

  def required_prices
    [:electricity]
  end

  def carries_base_fee?
    true
  end

  def sql_calculation
    base_fee_sql
  end

  # Nothing of its own: the fee is added by
  # Sensor::Definitions::FinanceBase#with_base_fee, the same way every other
  # sensor that carries the fee gets it. Without a fee the value stays nil
  # rather than zero, so a tariff without a base fee shows no row instead of an
  # empty one.
  def calculate_with_prices(**)
    nil
  end
end
