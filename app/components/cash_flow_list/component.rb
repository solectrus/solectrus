class CashFlowList::Component < ViewComponent::Base
  def initialize(cash_flows:)
    super()
    @cash_flows = cash_flows
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
end
