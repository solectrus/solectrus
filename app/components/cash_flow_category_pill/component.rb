class CashFlowCategoryPill::Component < ViewComponent::Base
  def initialize(category:)
    super()
    @category = category
  end

  def call
    tag.span(label, class: pill_class)
  end

  private

  attr_reader :category

  def label
    CashFlow.human_enum_name(:category, category)
  end

  BASE =
    'inline-flex items-center rounded-full px-2 py-0.5 text-xs ' \
    'font-semibold uppercase tracking-wide whitespace-nowrap ring-1 ring-inset'.freeze
  private_constant :BASE

  # Colour by economic effect so a pill's hue tells what it does: the investment
  # stands on its own (indigo); the inflows subsidy/refund/compensation share a
  # green family (money coming in); the running costs operating_cost/repair share
  # a red/warm family; other stays a neutral amber. Within a family the categories
  # use distinct but related hues at the same brightness, not lightness steps.
  # Dark mode uses a faint tint + coloured ring instead of a filled background, so
  # the pills stay clearly distinguishable without dominating the dark page.
  # Literal class strings (not built from parts) so Tailwind's scanner keeps them.
  COLORS = {
    'investment' => 'bg-indigo-100 text-indigo-700 ring-indigo-300 dark:bg-indigo-400/10 dark:text-indigo-300 dark:ring-indigo-400/30',
    # Inflows (green family)
    'subsidy' => 'bg-lime-100 text-lime-700 ring-lime-300 dark:bg-lime-400/10 dark:text-lime-400 dark:ring-lime-400/30',
    'refund' => 'bg-green-100 text-green-700 ring-green-300 dark:bg-green-400/10 dark:text-green-300 dark:ring-green-400/30',
    'compensation' => 'bg-teal-100 text-teal-700 ring-teal-300 dark:bg-teal-400/10 dark:text-teal-300 dark:ring-teal-400/30',
    # Running costs (red/warm family)
    'operating_cost' => 'bg-red-100 text-red-700 ring-red-300 dark:bg-red-400/10 dark:text-red-300 dark:ring-red-400/30',
    'repair' => 'bg-orange-100 text-orange-700 ring-orange-300 dark:bg-orange-400/10 dark:text-orange-300 dark:ring-orange-400/30',
    # Neutral
    'other' => 'bg-amber-100 text-amber-700 ring-amber-300 dark:bg-amber-400/10 dark:text-amber-300 dark:ring-amber-400/30',
  }.freeze
  private_constant :COLORS

  def pill_class
    [BASE, COLORS[category]]
  end
end
