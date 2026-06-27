class Sensor::Definitions::CustomCostsPv < Sensor::Definitions::FinanceBase
  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  attr_reader :number

  def name
    :"custom_#{formatted_number}_costs_pv"
  end

  depends_on do
    [
      :"custom_power_#{formatted_number}",
      :"custom_power_#{formatted_number}_grid",
    ]
  end

  # Deps derive purely from the consumer number; expose them statically so
  # Sensor::Config#exists? prunes this sensor when its consumer is unconfigured
  # (block-form depends_on alone would leak a phantom for every slot).
  def static_dependencies = dependencies

  def required_prices
    [:feed_in]
  end

  def sql_calculation
    "GREATEST(COALESCE(custom_power_#{formatted_number}_sum,0) - COALESCE(custom_power_#{formatted_number}_grid_sum,0), 0) / 1000.0 * pf_eur_per_kwh"
  end

  def calculate_with_prices(prices:, **values)
    feed_in_price = prices[:feed_in]
    return unless feed_in_price

    custom_power = values[:"custom_power_#{formatted_number}"]
    custom_power_grid = values[:"custom_power_#{formatted_number}_grid"]
    return unless custom_power && custom_power_grid

    pv_power = [custom_power - custom_power_grid, 0].max
    pv_power / 1000.0 * feed_in_price
  end

  private

  def formatted_number
    format('%02d', number)
  end
end
