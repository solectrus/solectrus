# The navigation on the side of a page with pages of its own, like the cars
# and their places in the settings. Each item links to a URL of its own. The
# navigation stays in view at the side while the page scrolls, in a tinted
# column. The title of the current page heads the content. A phone shows no
# such navigation, and neither does a single page.
class Ui::SideNav::Component < ViewComponent::Base
  # items: [{ name:, href:, title: }], the title heads the content and falls
  # back to the name
  def initialize(items:)
    super()
    @items = items
  end

  attr_reader :items

  def current?(item) = helpers.current_page?(item[:href])

  def current_item = items.find { current?(it) }

  # Each page is a tab that reaches to the border of the column. The current
  # one covers the border and merges into the content beside it.
  def link_class(item)
    base = 'flex py-2 px-3 border-y border-l rounded-l-lg'

    if current?(item)
      "#{base} -mr-px font-semibold bg-white text-indigo-700 border-gray-200 " \
        'dark:bg-slate-900 dark:text-indigo-300 dark:border-slate-800'
    else
      "#{base} font-medium border-transparent text-gray-600 hover:bg-gray-200/70 hover:text-gray-900 " \
        'dark:text-gray-400 dark:hover:bg-slate-900/50 dark:hover:text-gray-200'
    end
  end
end
