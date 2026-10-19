# The chevron beside a value of a row that narrows the list to this value,
# like the category of the row (see Ui::FilterBar). It shows while the
# pointer rests on the row, so the row needs the class `group`. It is a
# link of its own, so a click on it does not open the entry of the row.
#
# `filter:` is the filter of the list, `narrowed:` the filter of the link,
# like `filter.with_year(date)`, and `label:` the tooltip. A link that would
# not change the filter does not show.
class Ui::FilterLink::Component < ViewComponent::Base
  CSS_CLASS =
    'text-gray-400 dark:text-gray-500 hover:text-indigo-600 dark:hover:text-indigo-400 ' \
    'opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity'.freeze
  private_constant :CSS_CLASS

  def initialize(filter:, narrowed:, label:)
    super()
    @filter = filter
    @narrowed = narrowed
    @label = label
  end

  def render? = @narrowed != @filter

  def call
    link_to helpers.filter_path(@narrowed),
            class: CSS_CLASS,
            data: { turbo_frame: '_top', controller: 'tooltip' },
            title: @label,
            'aria-label': @label do
      helpers.icon('chevron-right', class: 'text-xs')
    end
  end
end
