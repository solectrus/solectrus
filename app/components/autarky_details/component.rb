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

  # Autarky = 100 - grid quote
  def autarky_formula
    safe_join(
      [
        Sensor::Registry[:autarky].display_name(:short),
        "\u00A0=\u00A0100 −\u00A0",
        render(SensorValue::Component.new(data, :grid_quote)),
      ],
    )
  end

  def power_or_energy
    timeframe.now? ? :rate : :total
  end
end
