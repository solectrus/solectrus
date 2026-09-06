# @label BalanceGap
class BalanceGapComponentPreview < ViewComponent::Preview
  # A consumer is missing from the measurement, so the sources deliver more than
  # the sinks account for.
  def missing_consumer
    render BalanceGap::Component.new data: data(house_power: 9_000_000.0)
  end

  # The opposite: the sinks record more than the sources deliver.
  def counted_twice
    render BalanceGap::Component.new data: data(house_power: 11_000_000.0)
  end

  # Sources and sinks match, so the component renders nothing at all.
  def balanced
    render BalanceGap::Component.new data: data
  end

  private

  # Sources: 9 MWh from the inverter plus 5 MWh from the grid.
  # Sinks: the house, 1 MWh for the wallbox and 3 MWh into the grid.
  # Grid energy costs 0.30 EUR/kWh here.
  def data(house_power: 10_000_000.0)
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          %i[grid_costs sum] => 1500.0,
          %i[inverter_power sum] => 9_000_000.0,
          %i[grid_import_power sum] => 5_000_000.0,
          %i[grid_export_power sum] => 3_000_000.0,
          %i[house_power sum] => house_power,
          %i[wallbox_power sum] => 1_000_000.0,
          %i[heatpump_power sum] => 0.0,
          %i[battery_charging_power sum] => 0.0,
          %i[battery_discharging_power sum] => 0.0,
        },
        timeframe:,
      ),
    )
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
