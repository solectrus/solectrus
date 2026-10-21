# The cash flows (see CashFlow): a grid on the desktop, whose rows open the
# form in the modal, and a grouped list on a phone, whose rows open the form
# on a page of its own (see Ui::TableRow::Component). The total is the sum
# of the cash flows of the filter.
class CashFlow::List::Component < ViewComponent::Base
  # The default filter gives the full, unfiltered list (see CashFlow::Filter)
  def initialize(cash_flows:, filter: CashFlow::Filter.new)
    super()
    @cash_flows = cash_flows
    @filter = filter
  end

  attr_reader :cash_flows, :filter

  def total = cash_flows.sum(&:amount)

  def headers = %i[date category note amount].map { CashFlow.human_attribute_name(it) }

  # An empty list without a filter introduces the cash flows. With a filter,
  # it only says that nothing matches.
  def empty_state
    if filter.active?
      Ui::EmptyState::Component.new(icon: 'filter', title: t('.empty_filtered'))
    else
      Ui::EmptyState::Component.new(icon: 'piggy-bank', title: t('.empty_title'), text: t('.empty'))
    end
  end
end
