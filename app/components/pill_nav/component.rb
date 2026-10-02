# A row of pills that links to the choices of a select. The current choice
# is highlighted, and a choice with a color shows it as a dot.
class PillNav::Component < ViewComponent::Base
  Item = Data.define(:label, :href, :current, :color)
  public_constant :Item

  def initialize(label:, items:, link_data: nil, classes: nil)
    super()
    @label = label
    @items = items
    @link_data = link_data
    @classes = classes
  end

  attr_reader :label, :items, :link_data, :classes

  PILL_CLASSES = 'click-animation flex items-center gap-2 rounded-full px-3 py-1 text-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400'.freeze
  private_constant :PILL_CLASSES

  def pill_classes(current)
    class_names(
      PILL_CLASSES,
      current ? 'bg-slate-700 text-white dark:bg-slate-300 dark:text-slate-900 font-semibold' : 'bg-slate-100 text-slate-600 hover:bg-slate-200 dark:bg-slate-800 dark:text-slate-400 dark:hover:bg-slate-700',
    )
  end
end
