# @label AutarkyDetails
class AutarkyDetailsComponentPreview < ViewComponent::Preview
  def default
    render AutarkyDetails::Component.new data:, timeframe:
  end

  private

  def data
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          %i[grid_import_power sum] => 2000.0,
          %i[house_power sum] => 8000.0,
          %i[wallbox_power sum] => 4000.0,
          %i[heatpump_power sum] => 1500.0,
          %i[total_consumption sum] => 13_500.0,
          %i[grid_quote avg] => 15.0,
          %i[autarky avg] => 85.0,
        },
        timeframe:,
      ),
    )
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
