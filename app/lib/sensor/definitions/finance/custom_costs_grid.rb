class Sensor::Definitions::CustomCostsGrid < Sensor::Definitions::FinanceBase
  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  attr_reader :number

  def name
    :"custom_#{formatted_number}_costs_grid"
  end

  depends_on { [:"custom_power_#{formatted_number}_grid"] }

  # Deps derive purely from the consumer number; expose them statically so
  # Sensor::Config#exists? prunes this sensor when its consumer is unconfigured
  # (block-form depends_on alone would leak a phantom for every slot).
  def static_dependencies = dependencies

  def required_prices
    [:electricity]
  end

  def sql_calculation
    "custom_power_#{formatted_number}_grid_sum * pb_money_per_kwh / 1000.0"
  end

  def calculate_with_prices(prices:, **values)
    electricity_price = prices[:electricity]
    return unless electricity_price

    custom_power_grid = values[:"custom_power_#{formatted_number}_grid"]
    return unless custom_power_grid

    custom_power_grid * electricity_price / 1000.0
  end

  private

  def formatted_number
    format('%02d', number)
  end
end
