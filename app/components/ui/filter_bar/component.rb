# The notice above a filtered list (see ListFilter and FilteredList): each
# part of the filter as a pill with a small x that removes this part, and a
# link that clears the whole filter. It has no controls to compose a filter,
# because date pickers proved unusable on a phone. The links of the list and
# of its rows set the filter instead (see Ui::FilterLink). It stands outside
# the frame of the list, so a refresh of the list after a save keeps it.
#
# `filter:` is the filter of the list. `category_pill:` is the component of
# a category, which takes `category:` and `remove_path:`, like
# CashFlow::CategoryPill::Component. A filter with members of its own adds
# a pill for each of them before the categories:
#
#   = render Ui::FilterBar::Component.new(filter:, category_pill: Car::PaymentCategoryPill::Component) do |bar|
#     - if filter.car
#       - bar.with_pill(icon: 'car', remove_path: filter_path(filter.without_car)) { filter.car.display_name }
class Ui::FilterBar::Component < ViewComponent::Base
  renders_many :pills, Ui::FilterBar::Pill::Component

  def initialize(filter:, category_pill:)
    super()
    @filter = filter
    @category_pill = category_pill
  end

  attr_reader :filter

  def render? = filter.active?

  def category_pill(category)
    @category_pill.new(category:, remove_path: path(filter.without_category(category)))
  end

  def dates_pill
    Ui::FilterBar::Dates::Component.new(from: filter.from, to: filter.to, remove_path: path(filter.without_dates))
  end

  def clear_path = path(filter.class.new)

  private

  def path(other) = helpers.filter_path(other)
end
