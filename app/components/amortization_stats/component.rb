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
           :profit_nominal,
           :npv,
           :irr_percent,
           :required_annual_savings,
           :savings_per_day,
           :savings_per_year,
           :projection_uncertain,
           :period_years,
           to: :result

  def currency(value, precision: 0)
    return t('.not_available') unless value

    number_to_currency(value, precision:, unit: Currency.symbol)
  end

  def percentage(value)
    return t('.not_available') unless value

    t('.percent_per_year', value: number_with_precision(value, precision: 1))
  end

  def signed_color(value)
    return 'text-gray-800 dark:text-gray-300' unless value

    value.negative? ? 'text-signal-negative' : 'text-signal-positive'
  end

  def stat_tile_class
    'relative flex flex-col justify-center rounded-xl ' \
      'bg-slate-200 dark:bg-slate-800 px-3 py-2.5 md:py-3'
  end

  # Renders the info icon with a rich-HTML tooltip. The hint text is split into
  # paragraphs on blank lines (\n\n), so long hints stay readable.
  #
  # The tooltip controller sits on the wrapper, not on the <i>: Font Awesome
  # replaces the <i> with an <svg> and discards its children, so the hidden
  # html-target must be a sibling of the icon. The wrapper carries the absolute
  # positioning so it has a real bounding box for the tooltip to anchor to.
  def info_icon(text)
    tag.span(
      class: 'absolute bottom-2 right-2 cursor-help',
      data: {
        controller: 'tooltip',
        tooltip_touch_value: 'true',
      },
    ) do
      safe_join(
        [
          tag.i(
            class:
              'fa fa-circle-info font-normal normal-case text-gray-400 dark:text-gray-500',
          ),
          tag.span(
            tooltip_paragraphs(text),
            class: 'hidden',
            data: {
              tooltip_target: 'html',
            },
          ),
        ],
      )
    end
  end

  def tooltip_paragraphs(text)
    safe_join(
      text.split("\n\n").map.with_index do |paragraph, index|
        tag.p(paragraph, class: ('mt-2' if index.nonzero?))
      end,
    )
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
end
