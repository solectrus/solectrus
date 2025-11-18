# @label ConsumptionDetails
class ConsumptionDetailsComponentPreview < ViewComponent::Preview
  def default
    render ConsumptionDetails::Component.new(data:, timeframe:)
  end

  private

  def data
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          %i[house_power sum] => 8000.0,
          %i[wallbox_power sum] => 4000.0,
          %i[heatpump_power sum] => 1500.0,
          %i[house_power_grid sum] => 1200.0,
          %i[wallbox_power_grid sum] => 800.0,
          %i[heatpump_power_grid sum] => 300.0,
          %i[inverter_power sum] => 15_000.0,
          %i[grid_export_power sum] => 5000.0,
          %i[self_consumption sum] => 10_000.0,
          %i[self_consumption_quote avg] => 70.0,
        },
        timeframe:,
      ),
    )
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
