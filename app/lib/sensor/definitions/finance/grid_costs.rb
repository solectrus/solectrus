# What the grid connection costs:
#
#   grid_costs = grid_energy_costs + grid_base_fee
#
# The energy drawn from the grid, plus the fixed fee the supplier charges for
# the connection itself. Composed from the two halves rather than calculating
# them itself, so the breakdown in the tooltip reads the very numbers this sum
# is made of, and neither backend can add the fee twice or not at all.
#
# traditional_costs carries the base fee as well - you pay it with or without
# PV, so it cancels out in savings and leaves the amortization untouched.
class Sensor::Definitions::GridCosts < Sensor::Definitions::FinanceBase
  value

  color background: 'bg-sensor-costs',
        text: 'text-white dark:text-red-200'

  depends_on %i[grid_energy_costs grid_base_fee]

  home_pages :balance

  chart { |timeframe| Sensor::Chart::GridCosts.new(timeframe:) }
  aggregations stored: false, computed: [:sum], meta: %i[sum min max], top10: true
  trend

  # A missing reading cancels the energy costs, but not the fee: the fee buys
  # the grid connection and falls due whether the meter reports or not, which is
  # what the COALESCE in grid_energy_costs says on the SQL side. Only when there
  # is neither is there nothing to report, and the value stays nil so a gap in
  # the data keeps reading as a gap.
  calculate do |grid_energy_costs:, grid_base_fee:, **|
    next if grid_energy_costs.nil? && grid_base_fee.nil?

    grid_energy_costs.to_f + grid_base_fee.to_f
  end

  def required_prices
    [:electricity]
  end

  def sql_calculation
    energy = Sensor::Registry[:grid_energy_costs].sql_calculation
    base_fee = Sensor::Registry[:grid_base_fee].sql_calculation

    "(#{energy}) + (#{base_fee})"
  end
end
