class Sensor::Definitions::CustomCostsGrid < Sensor::Definitions::FinanceBase
  include Sensor::Definitions::ConsumerGridCosts

  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  attr_reader :number

  def name
    :"custom_#{formatted_number}_costs_grid"
  end

  # Memoized: a definition is a cached singleton, but #power_sensor is asked
  # once per data point of a query.
  def power_sensor
    @power_sensor ||= :"custom_power_#{formatted_number}_grid"
  end

  private

  def formatted_number
    format('%02d', number)
  end
end
