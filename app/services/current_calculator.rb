class CurrentCalculator < BaseCalculator
  def initialize
    super

    build_context FluxQuery.new(
      :inverter_power,
      :house_power,
      :grid_power_plus,
      :grid_power_minus,
      :bat_power_minus,
      :bat_power_plus,
      :bat_fuel_charge
    ).current
  end
end
