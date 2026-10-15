# The cash flows: a table on the desktop, whose rows open the form in the
# modal, and a grouped list on a phone, whose rows open the form
# on a page of its own (see Ui::TableRow::Component).
class CashFlow::List::Component < ViewComponent::Base
  # The active filter is passed in as plain data. The defaults give the full,
  # unfiltered list.
  def initialize(cash_flows:, filter_categories: [], filter_from: nil, filter_to: nil)
    super()
    @cash_flows = cash_flows
    @filter_categories = filter_categories
    @filter_from = filter_from
    @filter_to = filter_to
  end

  attr_reader :cash_flows

  # The form leads back to this list (see ListAddress)
  def edit_path(cash_flow)
    helpers.edit_settings_cash_flow_path(cash_flow, return_to: helpers.list_address)
  end

  def total
    cash_flows.sum(&:amount)
  end

  # An empty list without a filter introduces the payments. With a filter, it
  # only says that nothing matches.
  def empty_text
    filtered = @filter_categories.any? || @filter_from || @filter_to
    t(filtered ? '.empty_filtered' : '.empty')
  end

  def formatted_amount(amount)
    number_to_currency(amount, precision: 2, unit: Currency.symbol)
  end

  def amount_color(amount)
    amount.negative? ? 'text-signal-negative' : 'text-signal-positive'
  end

  # Narrow the list to this row's category, preserving any active date range.
  def filter_path(cash_flow)
    helpers.settings_cash_flows_path(
      category: cash_flow.category,
      from: @filter_from,
      to: @filter_to,
    )
  end

  # Redundant to offer filtering to the category the list already shows alone.
  def filterable?(cash_flow)
    @filter_categories != [cash_flow.category]
  end
end
