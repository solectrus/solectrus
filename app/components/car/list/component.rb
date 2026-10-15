# The cars: a table on the desktop, whose rows open the form of the car in the
# modal, and a grouped list on a phone, whose rows open the form
# on a page of its own (see Ui::TableRow::Component).
class Car::List::Component < ViewComponent::Base
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
