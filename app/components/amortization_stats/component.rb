# Detail view (sponsor feature, shown to every visitor): key figures of the
# amortization calculation as stat tiles. The nominal payback date itself lives
# in the timeline (AmortizationDegree); here discounting is exposed as NPV
# instead of a second competing payback date.
class AmortizationStats::Component < ViewComponent::Base
  def initialize(result:)
    super()
    @result = result
  end

  attr_reader :result

  delegate :net_position,
           :gross_investment,
           :investment_reduction,
           :net_investment,
           :operating_cashflow,
           :profit_nominal,
           :npv,
           :irr_percent,
           :degree_percent,
           :required_annual_savings,
           :savings_per_day,
           :savings_per_year,
           :projection_uncertain,
           :period_years,
           to: :result

  # Whether the investment reduction (subsidy/refund) breakdown is worth showing
  # at all - only when something actually lowers the base. investment_reduction
  # is always numeric (0.0 when empty), never nil.
  def investment_reduced?
    investment_reduction.positive?
  end

  # Whole-percent amortization degree, floored at 0 - identical to the
  # AmortizationDegree headline and the chart's today marker, so all three agree.
  def display_degree
    return unless degree_percent

    [degree_percent.to_f, 0].max.round
  end

  def degree_text
    display_degree ? "#{display_degree} %" : t('.not_available')
  end

  def currency(value, precision: 0)
    return t('.not_available') unless value

    number_to_currency(value, precision:, unit: Currency.symbol)
  end

  def percentage(value)
    return t('.not_available') unless value

    t('.percent', value: number_with_precision(value, precision: 1))
  end

  def signed_color(value)
    return 'text-gray-800 dark:text-gray-300' unless value

    value.negative? ? 'text-signal-negative' : 'text-signal-positive'
  end

  # Compact tiles for the secondary KPI rail below the chart (the headline
  # figures now live as annotations on the curve).
  def stat_tile_class
    'relative flex flex-col justify-center rounded-lg ' \
      'bg-slate-200 dark:bg-slate-800 px-2.5 py-2'
  end

  def stat_label_class
    'flex items-center justify-center gap-1 px-2 text-[10px] md:text-xs xl:text-sm ' \
      'uppercase tracking-wide font-semibold text-gray-500 dark:text-gray-400'
  end

  def stat_value_class
    'mt-0.5 text-base md:text-lg font-bold tabular-nums'
  end

  # Info icon in the tile's bottom-right corner, carrying the hint as a tooltip.
  def info_icon(text)
    render InfoIcon::Component.new(text:)
  end

  def npv_hint
    hint = t('.npv_hint', rate: rate_label, years: period_years)
    return hint if npv.nil?

    verdict = npv.negative? ? t('.npv_hint_negative') : t('.npv_hint_positive')
    "#{hint}\n\n#{verdict}"
  end

  def savings_per_year_hint
    hint =
      t(
        '.savings_per_year_hint',
        per_day: currency(savings_per_day, precision: 2),
      )
    return hint unless required_annual_savings

    [
      hint,
      t(
        '.required_annual_hint',
        value: currency(required_annual_savings),
        rate: rate_label,
      ),
    ].join("\n\n")
  end

  def rate_label
    number_with_precision(result.interest_rate, precision: 1)
  end

  # Explains the net investment and, when a subsidy/refund actually lowered it,
  # shows the gross - reduction breakdown.
  def net_investment_hint
    hint = t('.net_investment_hint')
    return hint unless investment_reduced?

    [
      hint,
      t(
        '.net_investment_breakdown',
        gross: currency(gross_investment),
        reduction: currency(investment_reduction),
      ),
    ].join("\n\n")
  end
end
