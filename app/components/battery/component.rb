class Battery::Component < ViewComponent::Base
  def initialize(fuel_charge:, temperature:)
    super
    @fuel_charge = fuel_charge
    @temperature = temperature
  end

  attr_reader :fuel_charge, :temperature

  def temperature_color
    if temperature < 20
      'text-blue-600'
    elsif temperature > 40
      'text-red-600'
    else
      'text-green-600'
    end
  end
end
