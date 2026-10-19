# The filter of a list of entries: some categories and a range of dates,
# each optional. A Data with the members `categories`, `from` and `to`
# includes it, and can add members of its own, like a car. It names its
# categories in `category_keys`.
#
# A link of the list sets the filter in the query of the list (see
# FilteredList). A value that does not fit, like an unknown category or a
# date that does not parse, stays out. A filter equals another one with the
# same values, so a link that would not change the filter can hide (see
# Ui::FilterLink).
#
#   CashFlow::Filter = Data.define(:categories, :from, :to) do
#     include ListFilter
#     def self.category_keys = CashFlow.categories.keys
#   end
module ListFilter
  extend ActiveSupport::Concern

  class_methods do
    # The filter from the query of the list. A class with members of its own
    # adds them to the result with `with`.
    def from_params(params)
      params = params.to_h.with_indifferent_access
      new(
        categories: Array(params[:category]).map(&:to_s) & category_keys,
        from: parse_date(params[:from]),
        to: parse_date(params[:to]),
      )
    end

    private

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end

  # Each member can stay out: the categories are then empty, the rest nil
  def initialize(**members)
    super(**self.class.members.index_with(nil).merge(categories: []).merge(members))
  end

  def active? = categories.any? || from.present? || to.present?

  # The entries of the filter, of all of them in the scope
  def apply(scope)
    scope = scope.where(category: categories) if categories.any?
    scope = scope.where(date: from..) if from
    scope = scope.where(date: ..to) if to
    scope
  end

  # The query of the list with this filter
  def to_params = { category: categories.presence, from: from&.iso8601, to: to&.iso8601 }.compact

  # The filter with a single category or the year of a date, for a link
  # that narrows the list
  def with_category(category) = with(categories: [category])
  def with_year(date) = with(from: date.beginning_of_year, to: date.end_of_year)

  # The filter without a category or without the dates, for the x of a pill
  def without_category(category) = with(categories: categories - [category])
  def without_dates = with(from: nil, to: nil)

  # The year of the range, nil for another range
  def year = (from.year if from && to && from == from.beginning_of_year && to == from.end_of_year)
end
