class ConsumptionDetails::Component < ViewComponent::Base
  def initialize(data:, timeframe:)
    super()
    @data = data
    @timeframe = timeframe
  end

  attr_accessor :data, :timeframe

  # Self-consumption = PV - grid export, with one rounding, so it visibly adds
  # up
  def self_consumption
    @self_consumption ||=
      RoundedSum.new(
        [data.inverter_power, data.grid_export_power && -data.grid_export_power],
        range: Sensor::Registry[:self_consumption].value_range,
        unit: :watt,
        **consistent_options,
      )
  end

  def power_or_energy
    timeframe.now? ? :rate : :total
  end

  private

  def consistent_options
    max = [
      data.inverter_power,
      data.grid_export_power,
      data.self_consumption,
    ].compact.max

    { context: power_or_energy, scaling: max, precision: 3 }
  end
end
