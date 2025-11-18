# @label StatsRange
class StatsRangeComponentPreview < ViewComponent::Preview
  def default
    render StatsRange::Component.new(data:, timeframe:, sensor:)
  end

  private

  def data
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          %i[inverter_power sum] => 15_000.0,
          %i[house_power sum] => 8000.0,
          %i[grid_import_power sum] => 2000.0,
          %i[grid_export_power sum] => 5000.0,
          %i[battery_charging_power sum] => 3000.0,
          %i[battery_discharging_power sum] => 2500.0,
          %i[wallbox_power sum] => 4000.0,
          %i[heatpump_power sum] => 1500.0,
          %i[autarky avg] => 85.0,
          %i[self_consumption_quote avg] => 70.0,
          %i[co2_reduction sum] => 250_000.0,
          %i[grid_revenue sum] => 15.0,
          %i[total_costs sum] => 80.0,
          %i[savings sum] => 125.50,
          %i[total_consumption sum] => 13_500.0,
          %i[grid_quote avg] => 15.0,
          %i[self_consumption sum] => 10_000.0,
          %i[grid_costs sum] => 50.0,
          %i[opportunity_costs sum] => 30.0,
          %i[traditional_costs sum] => 180.0,
          %i[solar_price sum] => -30.0,
          %i[battery_savings sum] => 25.0,
          %i[battery_savings_percent avg] => 20.0,
          %i[wallbox_costs sum] => 20.0,
          %i[heatpump_costs sum] => 10.0,
          %i[house_costs sum] => 25.0,
          %i[battery_charging_costs sum] => 15.0,
        },
        timeframe:,
      ),
    )
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end

  def sensor
    :grid_import_power
  end
end
