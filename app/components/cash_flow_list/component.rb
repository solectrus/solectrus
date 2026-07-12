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

  def category_label(cash_flow)
    CashFlow.human_enum_name(:category, cash_flow.category)
  end

  PILL_BASE =
    'inline-flex items-center rounded-full px-2 py-0.5 text-[10px] ' \
    'font-semibold uppercase tracking-wide whitespace-nowrap'.freeze
  private_constant :PILL_BASE

  # Subtle semantic colouring so the effect of a category (investment base,
  # income, cost, neutral) is recognisable at a glance.
  PILL_COLORS = {
    'investment' => 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900 dark:text-indigo-200',
    'subsidy' => 'bg-teal-100 text-teal-700 dark:bg-teal-900 dark:text-teal-200',
    'refund' => 'bg-teal-100 text-teal-700 dark:bg-teal-900 dark:text-teal-200',
    'compensation' => 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-200',
    'operating_cost' => 'bg-amber-100 text-amber-700 dark:bg-amber-900 dark:text-amber-200',
    'repair' => 'bg-amber-100 text-amber-700 dark:bg-amber-900 dark:text-amber-200',
    'other' => 'bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-300',
  }.freeze
  private_constant :PILL_COLORS

  def category_pill_class(cash_flow)
    "#{PILL_BASE} #{PILL_COLORS[cash_flow.category]}"
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
