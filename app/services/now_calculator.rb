class NowCalculator < BaseCalculator
  def initialize
    super

    build_context FluxSum.new(
      :inverter_power,
      :house_power,
      :wallbox_charge_power,
      :grid_power_plus,
      :grid_power_minus,
      :bat_power_minus,
      :bat_power_plus,
      :bat_fuel_charge
    ).now
  end
end
