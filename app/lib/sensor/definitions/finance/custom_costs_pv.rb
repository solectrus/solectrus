class Sensor::Definitions::CustomCostsPv < Sensor::Definitions::FinanceBase
  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  attr_reader :number

  def name
    :"custom_costs_#{formatted_number}_pv"
  end

  depends_on do
    [
      :"custom_power_#{formatted_number}",
      :"custom_power_#{formatted_number}_grid",
    ]
  end

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    "GREATEST(COALESCE(custom_power_#{formatted_number}_sum,0) - COALESCE(custom_power_#{formatted_number}_grid_sum,0), 0) / 1000.0 * pf_eur_per_kwh"
  end

  private

  def formatted_number
    format('%02d', number)
  end
end
