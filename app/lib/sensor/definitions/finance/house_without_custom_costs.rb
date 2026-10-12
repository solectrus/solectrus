class Sensor::Definitions::HouseWithoutCustomCosts < Sensor::Definitions::Base
  value unit: :money, category: :economic

  depends_on { static_dependencies + base_fee_dependencies }

  def static_dependencies
    %i[house_power house_power_without_custom house_costs]
  end

  # The base fee in house_costs, which is the whole grid_base_fee (see
  # Sensor::Definitions::HouseCostsGrid). Optional: a house without it carries
  # no fee, and nothing is taken out.
  def base_fee_dependencies
    Sensor::Registry[:house_costs_grid].carries_base_fee? ? [:grid_base_fee] : []
  end

  # The energy costs are split by the power share. The base fee is not: no
  # custom consumer carries a share of it, so it stays with the rest of the
  # house in full.
  calculate do |house_power_without_custom:, house_costs:, house_power:, grid_base_fee: nil, **|
    return unless house_power_without_custom && house_costs && house_power
    return if house_power.zero?

    fee = grid_base_fee.to_f
    (house_power_without_custom / house_power * (house_costs - fee)) + fee
  end

  aggregations stored: false, computed: [:sum]
end
