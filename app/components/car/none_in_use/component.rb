# The note that no car is in use, in the live view and in a period. The
# admin gets a link to the settings of the cars, where the period of use of
# each car lives. In the center of the empty gauge of the live view, the
# note comes with the icon of a car, and its size follows the gauge.
class Car::NoneInUse::Component < ViewComponent::Base
  def initialize(text:, gauge: false)
    super()
    @text = text
    @gauge = gauge
  end

  attr_reader :text

  def gauge? = @gauge

  LINK_CLASS =
    'inline-flex items-center gap-2 rounded-full px-4 py-1.5 text-sm font-medium ' \
    'bg-indigo-50 text-indigo-700 hover:bg-indigo-100 ' \
    'dark:bg-indigo-950/60 dark:text-indigo-300 dark:hover:bg-indigo-900/60 ' \
    'transition-colors click-animation'.freeze
  private_constant :LINK_CLASS

  def link_class = LINK_CLASS
end
