# @label ConsumeDetails
class ConsumeDetailsComponentPreview < ViewComponent::Preview
  def default
    render ConsumeDetails::Component.new data:
  end

  private

  def data
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          %i[house_power sum] => 8000.0,
          %i[wallbox_power sum] => 4000.0,
          %i[heatpump_power sum] => 1500.0,
          %i[grid_import_power sum] => 2000.0,
          %i[grid_costs sum] => 50.0,
          %i[self_consumption sum] => 10_000.0,
          %i[opportunity_costs sum] => 30.0,
          %i[total_costs sum] => 80.0,
        },
        timeframe:,
      ),
    )
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
