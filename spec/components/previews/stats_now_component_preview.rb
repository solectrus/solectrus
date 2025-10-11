# @label StatsNow
class StatsNowComponentPreview < ViewComponent::Preview
  def default
    render StatsNow::Component.new data:, sensor:
  end

  private

  def data
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          inverter_power: 2500.0,
          house_power: 1200.0,
          heatpump_power: 800.0,
          wallbox_power: 500.0,
          battery_charging_power: 300.0,
          battery_discharging_power: 0.0,
          grid_import_power: 0.0,
          grid_export_power: 200.0,
          battery_soc: 75.0,
          car_battery_soc: 80.0,
          wallbox_car_connected: true,
          autarky: 85.0,
          self_consumption_quote: 70.0,
          self_consumption: 2300.0,
          case_temp: 32.5,
          total_consumption: 2500.0,
          grid_quote: 15.0,
        },
        timeframe: Timeframe.now,
        time: Time.current,
      ),
    )
  end

  def sensor
    :inverter_power
  end
end
