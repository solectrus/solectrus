# The odometer of the car as a mechanical counter: one box for each digit,
# with six digits at least.
class Car::Odometer::Component < ViewComponent::Base
  MIN_DIGITS = 6
  private_constant :MIN_DIGITS

  def initialize(value:)
    super()
    @value = value
  end

  attr_reader :value

  def render?
    value.present?
  end

  def digits
    value.round.to_s.rjust(MIN_DIGITS, '0').chars
  end
end
