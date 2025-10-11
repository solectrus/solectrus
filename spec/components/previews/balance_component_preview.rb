# @label Balance
class BalanceComponentPreview < ViewComponent::Preview
  def default
    render Balance::Component.new timeframe: Timeframe.day, data:, sensor:
  end

  def with_peak
    render Balance::Component.new timeframe: Timeframe.now,
                                  data:,
                                  sensor:,
                                  peak:
  end

  private

  def data
    @data ||=
      PowerBalance.new(
        Sensor::Data::Single.new(
          {
            %i[inverter_power sum] => 900.0,
            %i[grid_import_power sum] => 1000.0,
            %i[battery_discharging_power sum] => 300.0,
            %i[grid_export_power sum] => 150.0,
            %i[battery_charging_power sum] => 200.0,
            %i[house_power sum] => 500.0,
            %i[heatpump_power sum] => 50.0,
            %i[wallbox_power sum] => 1300.0,
            %i[grid_costs sum] => 25.0,
            %i[grid_revenue sum] => 5.0,
            %i[wallbox_costs sum] => 30.0,
            %i[heatpump_costs sum] => 8.0,
            %i[house_costs sum] => 15.0,
            %i[battery_charging_costs sum] => 10.0,
          },
          timeframe: Timeframe.day,
        ),
      )
  end

  def sensor
    :inverter_power
  end

  def peak
    # All at maximum power
    {
      inverter_power: 900,
      grid_import_power: 1000,
      battery_discharging_power: 300,
      grid_export_power: 150,
      battery_charging_power: 200,
      house_power: 500,
      heatpump_power: 50,
      wallbox_power: 1300,
    }
  end
end
