# A tab of the sub navigation that opens a menu instead of leading somewhere.
# It looks like every other tab, plus the caret that says so. Only the current
# tab has a menu to open, so it always wears the look of the current tab.
class Nav::Sub::Menu::Component < ViewComponent::Base
  include NavTabLook

  def initialize(name:, items:, abbreviate:)
    super()
    @name = name
    @items = items
    @current = true
    @abbreviate = abbreviate
  end

  attr_reader :items

  def menu_classes
    'absolute z-20 right-0 origin-top-right mt-2 py-1 w-max rounded-md ' \
      'shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black/5 hidden ' \
      'max-sm:hidden overflow-hidden normal-case tracking-normal text-sm ' \
      'text-gray-700 dark:text-gray-400'
  end

  # `uppercase` again, because a button does not inherit the text-transform of
  # the nav: the browser resets it on form controls. `cursor-pointer` for the
  # same reason, because a button is not a link. `relative` carries the caret,
  # which hangs in the padding of the pill.
  def button_classes
    (css_classes - %w[flex-1 lg:landscape:flex-initial]) +
      %w[relative w-full uppercase select-none cursor-pointer]
  end

  def entry_classes(item)
    [
      'block py-3 px-4 text-left hover:bg-gray-100 dark:hover:bg-gray-700',
      ('font-bold' if item[:current]),
    ]
  end
end
