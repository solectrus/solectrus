# A cash flow in the list (see CashFlow::List::Component): a row of the grid
# on the desktop and a cell of a grouped list on a phone. On the desktop, a
# chevron beside the date and the category narrows the list to the year or
# the category of the row (see CashFlow::Filter). It shows while the pointer
# rests on the row, and not for a value that the filter holds already.
class CashFlow::List::Row::Component < ViewComponent::Base
  def initialize(cash_flow:, filter:)
    super()
    @cash_flow = cash_flow
    @filter = filter
  end

  attr_reader :cash_flow, :filter

  # The form leads back to this list (see ListAddress)
  def edit_path = helpers.edit_settings_cash_flow_path(cash_flow, return_to: helpers.list_address)

  def category_name = CashFlow.human_enum_name(:category, cash_flow.category)

  def amount = number_to_currency(cash_flow.amount, precision: 2, unit: Currency.symbol)

  def amount_color = cash_flow.amount.negative? ? 'text-signal-negative' : 'text-signal-positive'
end
