# A short label in a colored pill, like the category of an entry. `color:`
# names the hue. The content is the label. With `remove_path:`, a small x
# follows it, which removes the pill from a filter (see Ui::RemoveLink).
#
# Dark mode uses a faint tint and a colored ring instead of a filled
# background, so the pills stay clearly distinguishable without dominating
# the dark page. Literal class strings (not built from parts) so Tailwind's
# scanner keeps them.
class Ui::Badge::Component < ViewComponent::Base
  BASE =
    'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs ' \
    'font-semibold uppercase tracking-wide whitespace-nowrap ring-1 ring-inset'.freeze
  private_constant :BASE

  COLORS = {
    indigo: 'bg-indigo-100 text-indigo-700 ring-indigo-300 dark:bg-indigo-400/10 dark:text-indigo-300 dark:ring-indigo-400/30',
    lime: 'bg-lime-100 text-lime-700 ring-lime-300 dark:bg-lime-400/10 dark:text-lime-400 dark:ring-lime-400/30',
    green: 'bg-green-100 text-green-700 ring-green-300 dark:bg-green-400/10 dark:text-green-300 dark:ring-green-400/30',
    teal: 'bg-teal-100 text-teal-700 ring-teal-300 dark:bg-teal-400/10 dark:text-teal-300 dark:ring-teal-400/30',
    emerald: 'bg-emerald-100 text-emerald-700 ring-emerald-300 dark:bg-emerald-400/10 dark:text-emerald-300 dark:ring-emerald-400/30',
    red: 'bg-red-100 text-red-700 ring-red-300 dark:bg-red-400/10 dark:text-red-300 dark:ring-red-400/30',
    orange: 'bg-orange-100 text-orange-700 ring-orange-300 dark:bg-orange-400/10 dark:text-orange-300 dark:ring-orange-400/30',
    amber: 'bg-amber-100 text-amber-700 ring-amber-300 dark:bg-amber-400/10 dark:text-amber-300 dark:ring-amber-400/30',
  }.freeze
  private_constant :COLORS

  def initialize(color:, remove_path: nil)
    super()
    @color = color
    @remove_path = remove_path
  end

  def call
    tag.span(class: [BASE, COLORS[@color]]) do
      safe_join([content, (render Ui::RemoveLink::Component.new(href: @remove_path) if @remove_path)].compact)
    end
  end
end
