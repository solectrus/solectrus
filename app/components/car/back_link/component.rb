# The way back to the car page, before the title of a list of the cars in
# the header: the visits and the charging sessions. `css_class` adds the
# classes of its place in the header.
class Car::BackLink::Component < ViewComponent::Base
  CLASSES = 'flex items-center px-2 py-2 rounded-sm text-indigo-200 dark:text-gray-400 hover:bg-indigo-500 hover:text-white dark:hover:bg-indigo-950/50 dark:hover:text-gray-300 focus:ring-2 focus:ring-gray-300 focus:ring-offset-0 focus:outline-none dark:focus:ring-gray-400'.freeze
  private_constant :CLASSES

  def initialize(path:, css_class: nil)
    super()
    @path = path
    @css_class = css_class
  end

  attr_reader :path

  def classes = [CLASSES, @css_class].compact.join(' ')
end
