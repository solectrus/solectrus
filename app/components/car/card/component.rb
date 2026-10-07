# The frame of a card on the car page in a period: the block on top, the
# title below. Charging stands on the left and driving on the right, like
# the source and the usage of the power balance.
class Car::Card::Component < ViewComponent::Base
  # A row of the driving card: the rows stand one below the other, divided
  # by a line, close below the distance. A phone shows them as tiles, in a
  # card without a frame.
  ROW =
    'flex flex-col items-center min-w-0 text-center sm:py-4 md:py-6 ' \
    'border-t border-slate-200 dark:border-slate-700 ' \
    'max-sm:border-t-0 max-sm:rounded-lg max-sm:py-2 max-sm:bg-slate-100 max-sm:dark:bg-slate-800/60'.freeze
  public_constant :ROW

  # A value in a row of the driving card. Two values stand side by side, so
  # the size grows with the width of the rows, which are a container (see
  # Car::DrivingCard::Component). A phone has the width, but not the height,
  # so there the size stays. The costs stand out, so their values are larger
  # than the consumption and the range.
  ROW_VALUE =
    'text-xl sm:text-[clamp(1.25rem,8cqi,2rem)] font-semibold tabular-nums whitespace-nowrap text-slate-700 dark:text-slate-200'.freeze
  public_constant :ROW_VALUE

  COST_VALUE =
    'text-2xl sm:text-[clamp(1.5rem,11cqi,2.75rem)] font-semibold tabular-nums whitespace-nowrap text-slate-700 dark:text-slate-200'.freeze
  public_constant :COST_VALUE

  # The caption below such a value
  ROW_CAPTION = 'text-sm whitespace-nowrap text-slate-500 dark:text-slate-400'.freeze
  public_constant :ROW_CAPTION

  def initialize(title:)
    super()
    @title = title
  end

  attr_reader :title
end
