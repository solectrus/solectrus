class ConsumptionDetails::Component < ViewComponent::Base
  def initialize(data:, timeframe:)
    super()
    @data = data
    @timeframe = timeframe
  end

  attr_accessor :data, :timeframe

  def consistent_options
    max = [
      data.inverter_power,
      data.grid_export_power,
      data.self_consumption,
    ].compact.max

    { context: power_or_energy, scaling: max, precision: 3 }
  end

  def power_or_energy
    timeframe.now? ? :power : :energy
  end
end
