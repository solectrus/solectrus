# @label SavingsDetails
class SavingsDetailsComponentPreview < ViewComponent::Preview
  def default
    render SavingsDetails::Component.new data:
  end

  private

  def data
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          %i[savings sum] => 125.50,
          %i[traditional_costs sum] => 180.0,
          %i[grid_costs sum] => 45.0,
          %i[grid_revenue sum] => 15.0,
          %i[solar_price sum] => -30.0,
          %i[battery_savings sum] => 25.0,
          %i[battery_savings_percent avg] => 20.0,
          %i[co2_reduction sum] => 250_000.0,
        },
        timeframe:,
      ),
    )
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
