# Table view of the amortization calculation: one row per PV year with the
# year's measured savings, its cash flows broken out per category, the resulting
# cumulative nominal balance and how much of the net investment has been earned
# back. The alternative to the balance chart (AmortizationChart) - same
# yearly_series data, but the figures behind the curve shown exactly so the
# calculation can be followed year by year. savings plus all category cells add
# up to the balance change, so the running balance stays traceable.
class AmortizationTable::Component < ViewComponent::Base
  def initialize(result:)
    super()
    @result = result
  end

  attr_reader :result

  def rows
    result.yearly_table
  end

  # The seven per-category cash-flow columns folded into three grouped columns:
  # the one-off investment, the investment-reducing grants/refunds, and the
  # ongoing operating items. Keeps the table narrow enough to fit without
  # horizontal scrolling while still breaking the figures out per category -
  # inside a grouped cell the present categories are stacked (see the template).
  # The grouping mirrors the stats KPIs (gross investment, subsidy/refund,
  # operating cash flow).
  GROUPS = [
    { key: 'investment', categories: %w[investment] },
    { key: 'investment_reduction', categories: %w[subsidy refund] },
    { key: 'operating', categories: %w[operating_cost repair compensation other] },
  ].freeze
  private_constant :GROUPS

  # Only the groups (and, within them, the categories) that actually occur, in
  # the canonical order - a system without repairs folds no repair flow into its
  # group, and a group whose categories never occur shows no column at all.
  def groups
    @groups ||=
      GROUPS.filter_map do |group|
        present =
          group[:categories].select do |category|
            rows.any? { |row| row[:flows].key?(category) }
          end
        next if present.empty?

        { key: group[:key], categories: present }
      end
  end

  def group_label(group)
    t(".groups.#{group[:key]}")
  end

  # Every column header carries a tooltip explaining the figure - the grouped
  # columns name the categories folded into them, the rest describe the value.
  # Returned as [label, hint, key] triples in display order; the key marks the
  # year column, which is pinned on phones.
  def header_columns
    [
      [t('.year'), t('.hints.year'), :year],
      *groups.map { |group| [group_label(group), t(".hints.#{group[:key]}"), :group] },
      [t('.savings'), t('.hints.savings'), :savings],
      [t('.balance'), t('.hints.balance'), :balance],
      [t('.npv'), t('.hints.npv'), :npv],
      [t('.degree'), t('.hints.degree'), :degree],
    ]
  end

  # Phone-only pinning for the year column: it stays put while the figures scroll
  # sideways, so a row never loses its label. `max-md:` scopes this to phones with
  # no desktop reset needed; the solid background matches the table's full-width
  # backdrop so the scrolling cells pass cleanly behind the pinned column.
  def year_column_class
    'max-md:sticky max-md:left-0 max-md:z-10 max-md:bg-white dark:max-md:bg-gray-900'
  end

  # Phones only: the heading row stays pinned to the top of the table's (capped)
  # scroll area while the rows scroll under it. Its own solid background (matching
  # the full-width backdrop) covers the scrolling rows. The year heading is also
  # the pinned column, so it sits above both the other headings and the pinned
  # year cells scrolling up beneath it. Desktop keeps its plain, scrolling table.
  def header_cell_class(key)
    base = 'max-md:sticky max-md:top-0 max-md:bg-white dark:max-md:bg-gray-900'
    key == :year ? "#{base} max-md:left-0 max-md:z-30" : "#{base} max-md:z-20"
  end

  # The group's total for a row: the signed sum of its category flows, shown as
  # one calm figure per year instead of a line per category. nil when the group
  # has nothing this year (rendered as a dash).
  def group_sum(row, group)
    values = group[:categories].filter_map { |category| flow(row, category) }
    values.sum if values.any?
  end

  def flow(row, category)
    row[:flows][category]
  end

  # A dashed rule sets the forecast rows off from the measured ones: it sits on
  # the first projected row, but only when a measured row actually precedes it
  # (a system whose very first year is already a projection gets no rule). Border
  # goes on the cells, not the row - a CSS table-row paints no border.
  def separator_class(index)
    return unless rows[index][:projected] &&
      index.positive? && !rows[index - 1][:projected]

    'border-t-2 border-dashed border-gray-300 dark:border-gray-600'
  end

  # The row's exact date range (localized), shown as a tooltip on the year
  # number - PV years are not calendar years, so the span makes that explicit.
  def period_label(row)
    return unless row[:period]

    "#{l(row[:period].begin)} – #{l(row[:period].end)}"
  end

  # Link the measured savings to the balance page for the row's exact PV year -
  # the day-accurate range starting on the installation-date anniversary, so the
  # linked page shows precisely this figure. The row 0 baseline (no period),
  # projected years (no measured page) and empty savings stay plain text.
  def savings_path(row)
    return if row[:period].nil? || row[:projected] || row[:savings].round.zero?

    helpers.balance_home_path(
      sensor_name: 'savings',
      timeframe: "#{row[:period].begin}..#{row[:period].end}",
    )
  end

  # Drill down into the exact cash flows behind a grouped cell: the settings list
  # filtered to the group's categories (all at once) and the row's date range.
  # The row carries its own drill-down start (nil for year 1, which folds in
  # anything booked before the operating start), so the filter matches the figure
  # the cell shows. Admin-only, since the settings page is; other viewers see
  # plain amounts.
  def group_path(row, group)
    return unless helpers.admin? && row[:period]

    helpers.settings_cash_flows_path(
      category: group[:categories],
      from: row[:drilldown_from],
      to: row[:period].end,
    )
  end

  def currency(value)
    return '–' if value.nil?

    number_to_currency(value, precision: 0, unit: Currency.symbol)
  end

  # Whole euros like #currency, but a zero is shown as a dash too: the year is
  # the level of detail here, cents would only add noise, and an empty cell
  # keeps the table calm.
  def amount(value)
    return '–' if value&.round&.zero?

    currency(value)
  end

  # Whole-percent amortization degree, floored at 0 - identical to the chart's
  # today marker and the KPI, so all views agree. nil before the first debit.
  def degree(value)
    return '–' if value.nil?

    "#{[value, 0].max.round} %"
  end

  def signed_color(value)
    return 'text-gray-500 dark:text-gray-400' if value.nil? || value.zero?

    value.negative? ? 'text-signal-negative' : 'text-signal-positive'
  end
end
