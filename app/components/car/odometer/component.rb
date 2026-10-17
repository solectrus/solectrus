# The odometer of the car as a mechanical counter: one box for each digit,
# with six digits at least. Without a value, the counter stays as a frame:
# six inactive boxes with a dash, so the live view keeps its shape.
class Car::Odometer::Component < ViewComponent::Base
  MIN_DIGITS = 6
  private_constant :MIN_DIGITS

  # A compact counter is narrower, so it fits beside the name above the bar
  # of the battery (see Car::RangeBar::Component)
  def initialize(value:, compact: false)
    super()
    @value = value
    @compact = compact
  end

  attr_reader :value

  def active? = !value.nil?

  def compact? = @compact

  def digits
    return Array.new(MIN_DIGITS, '–') unless active?

    value.round.to_s.rjust(MIN_DIGITS, '0').chars
  end

  # The box of each digit. The class names stay literal, so Tailwind finds
  # them.
  def digit_classes
    @digit_classes ||= class_names(
      'flex items-center justify-center h-10 rounded-md font-mono',
      compact? ? 'w-[1.375rem] text-xl' : 'w-7 md:w-8 md:h-11 text-2xl md:text-3xl',
      if active?
        'bg-slate-500 dark:bg-slate-600 text-white dark:text-slate-100'
      else
        'bg-slate-100 dark:bg-slate-800 text-slate-300 dark:text-slate-600'
      end,
    )
  end
end
