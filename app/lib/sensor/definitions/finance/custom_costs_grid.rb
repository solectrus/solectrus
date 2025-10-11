class Sensor::Definitions::CustomCostsGrid < Sensor::Definitions::FinanceBase
  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  attr_reader :number

  def name
    :"custom_costs_#{formatted_number}_grid"
  end

  depends_on { [:"custom_power_#{formatted_number}_grid"] }

  def required_prices
    [:electricity]
  end

  def sql_calculation
    "custom_power_#{formatted_number}_grid_sum * pb_eur_per_kwh / 1000.0"
  end

  private

  def formatted_number
    format('%02d', number)
  end
end
