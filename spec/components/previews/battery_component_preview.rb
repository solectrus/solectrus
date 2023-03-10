# @label Battery Component
class BatteryComponentPreview < ViewComponent::Preview
  # @!group Misc

  def empty
    render Battery::Component.new(fuel_charge: 0, temperature: 20)
  end

  def low
    render Battery::Component.new(fuel_charge: 10, temperature: 20)
  end

  def medium
    render Battery::Component.new(fuel_charge: 55, temperature: 20)
  end

  def high
    render Battery::Component.new(fuel_charge: 80, temperature: 20)
  end

  def full
    render Battery::Component.new(fuel_charge: 100, temperature: 20)
  end

  def low_temperature
    render Battery::Component.new(fuel_charge: 45, temperature: 10)
  end

  def high_temperature
    render Battery::Component.new(fuel_charge: 50, temperature: 70)
  end

  # @!endgroup
end
