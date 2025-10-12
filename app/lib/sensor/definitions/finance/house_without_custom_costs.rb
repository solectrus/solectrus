class Sensor::Definitions::HouseWithoutCustomCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

  depends_on :house_power, :house_power_without_custom, :house_costs

  calculate do |house_power_without_custom:, house_costs:, house_power:, **|
    return unless house_power_without_custom && house_costs && house_power
    return if house_power.nonzero?

    house_power_without_custom / house_power * house_costs
  end

  aggregations stored: false, computed: [:sum]
end
