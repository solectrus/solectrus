# The navigation on the side of a settings page with pages of its own, for
# example the cars and their places. Unlike VerticalTabs::Component, each
# item links to a URL of its own. The navigation stays in view while the page
# scrolls: on a phone at the top, on a wider screen at the side.
class Nav::Side::Component < ViewComponent::Base
  # items: [{ name:, href: }]
  def initialize(items:)
    super()
    @items = items
  end

  attr_reader :items

  def current?(item) = helpers.current_page?(item[:href])

  def link_class(item)
    base = 'flex md:rounded-md py-3 md:py-2 px-3'

    if current?(item)
      "#{base} bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
    else
      "#{base} text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
    end
  end
end
