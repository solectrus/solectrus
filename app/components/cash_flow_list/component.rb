class CashFlowList::Component < ViewComponent::Base
  # The active filter is passed in as plain data (not read from the controller),
  # because the list is also re-rendered from a Turbo broadcast - where no
  # controller and no filter exist, so the defaults apply (full, unfiltered list).
  def initialize(cash_flows:, filter_categories: [], filter_from: nil, filter_to: nil)
    super()
    @cash_flows = cash_flows
    @filter_categories = filter_categories
    @filter_from = filter_from
    @filter_to = filter_to
  end

  attr_reader :cash_flows

  def total
    cash_flows.sum(&:amount)
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
