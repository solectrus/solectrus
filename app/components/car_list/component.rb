# The cars as a table: each row opens the form of the car in the modal.
class CarList::Component < ViewComponent::Base
  def initialize(cars:)
    super()
    @cars = cars
  end

  attr_reader :cars

  # The days a car is in use, from its first day to its last or today
  def period(car)
    until_text = car.active_until ? l(car.active_until) : t('settings.cars.today')
    "#{l(car.active_from)} – #{until_text}"
  end
end
