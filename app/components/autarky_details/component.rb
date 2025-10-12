class AutarkyDetails::Component < ViewComponent::Base
  def initialize(data:, timeframe:)
    super()
    @data = data
    @timeframe = timeframe
  end

  attr_accessor :data, :timeframe

  def consistent_options
    max = [data.grid_import_power, data.total_consumption].compact.max

    { context: power_or_energy, scaling: max }
  end

  def power_or_energy
    timeframe.now? ? :power : :energy
  end
end
