# @label StatsNow
class StatsNowComponentPreview < ViewComponent::Preview
  def default
    render StatsNow::Component.new calculator:, sensor:
  end

  private

  def calculator
    Calculator::Now.new(
      %i[
        inverter_power
        house_power
        heatpump_power
        wallbox_power
        battery_charging_power
        battery_discharging_power
        grid_import_power
        grid_export_power
        battery_soc
        car_battery_soc
        wallbox_car_connected
      ],
    )
  end

  def sensor
    :inverter_power
  end

  def timeframe
  end
end
