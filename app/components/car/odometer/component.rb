# The odometer of the car as a mechanical counter: one box for each digit,
# with six digits at least. Without a value, the counter stays as a frame:
# six inactive boxes with a dash, so the live view keeps its shape.
class Car::Odometer::Component < ViewComponent::Base
  MIN_DIGITS = 6
  private_constant :MIN_DIGITS

  def initialize(value:)
    super()
    @value = value
  end

  attr_reader :value

  def active? = !value.nil?

  def digits
    return Array.new(MIN_DIGITS, '–') unless active?

    value.round.to_s.rjust(MIN_DIGITS, '0').chars
  end

  # The class names stay literal, so Tailwind finds them
  def digit_classes
    if active?
      'bg-slate-800 dark:bg-slate-400 text-white dark:text-slate-950'
    else
      'bg-slate-100 dark:bg-slate-800 text-slate-300 dark:text-slate-600'
    end
  end
end
