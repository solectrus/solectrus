# The frame of a card on the car page in a period: the block on top, the
# title below. Charging stands on the left and driving on the right, like
# the source and the usage of the power balance.
class Car::Card::Component < ViewComponent::Base
  # A badge at the foot of a card: the charging sessions of the charging card
  # and the visits of the driving card. Side by side they are narrow, so
  # the label stands above the count.
  BADGE =
    'click-animation flex flex-col items-center justify-center min-w-0 ' \
    'rounded-lg px-2 md:px-3 py-2 sm:py-1 md:py-1.5 ' \
    'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400'.freeze
  public_constant :BADGE

  # A row of the driving card: the rows stand one below the other, divided
  # by a line, but without a line above the first. A phone shows them as
  # tiles, in a card without a frame. A short phone has less space above and
  # below the tiles.
  ROW =
    '@container min-w-0 sm:py-3 md:py-4 ' \
    'border-t first:border-t-0 border-slate-300 dark:border-slate-700 ' \
    'max-sm:flex max-sm:flex-col max-sm:justify-center ' \
    'max-sm:border-t-0 max-sm:rounded-lg max-sm:px-3 max-sm:py-2 max-sm:tiny:py-1 ' \
    'max-sm:bg-slate-100 max-sm:dark:bg-slate-800/60'.freeze
  public_constant :ROW

  # A value in a row of the driving card. The size grows with the width of
  # the row, which is a container.
  ROW_VALUE = 'text-xl @xs:text-2xl font-semibold tabular-nums whitespace-nowrap text-slate-700 dark:text-slate-200'.freeze
  public_constant :ROW_VALUE

  # The caption below such a value
  ROW_CAPTION = 'text-sm whitespace-nowrap text-slate-500 dark:text-slate-400'.freeze
  public_constant :ROW_CAPTION

  # A card alone on the page (`framed: false`) needs no frame and no title
  def initialize(title:, framed: true)
    super()
    @title = title
    @framed = framed
  end

  attr_reader :title

  def framed? = @framed
end
