class SavingsDetails::Component < ViewComponent::Base
  def initialize(data:)
    super()
    @data = data
  end

  attr_accessor :data

  # savings = traditional costs - solar price. The solar price comes first, so
  # it rounds as its own row does, and the traditional costs take the rest.
  def savings
    @savings ||=
      RoundedSum.new(
        [data.solar_price && -data.solar_price, data.traditional_costs],
        unit: :money,
        precision:,
      )
  end

  # solar price = grid costs - grid revenue
  def solar_price
    @solar_price ||=
      RoundedSum.new(
        [data.grid_costs, data.grid_revenue && -data.grid_revenue],
        unit: :money,
        precision:,
      )
  end

  private

  # Both sums share the finest digits that any of their amounts needs
  def precision
    @precision ||=
      RoundedSum.finest_formatter(
        [data.grid_costs, data.grid_revenue, data.solar_price, data.traditional_costs, data.savings],
        unit: :money,
      )&.precision
  end
end
