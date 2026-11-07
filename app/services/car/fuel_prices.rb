# The prices of a fuel of a car (EUR per liter), one price for each week
# (docs/cars.md). The comparison with a combustion car reads them (see
# Car::Comparison).
class Car::FuelPrices < FuelPrices
  # Whether a price of any fuel of a car exists
  def self.any? = super(Car.fuel_types.keys)
end
