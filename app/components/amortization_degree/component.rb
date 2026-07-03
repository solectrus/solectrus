# Public teaser: shows how far the PV system has amortized as a payback
# timeline - commissioning on the left, the projected break-even on the right,
# "today" marked in between with the current degree. Deliberately free of any
# currency amounts, so it can be shown to everyone.
class AmortizationDegree::Component < ViewComponent::Base
  def initialize(result:)
    super()
    @result = result
  end

  attr_reader :result

  delegate :amortized?,
           :prognosis?,
           :break_even_date,
           :commissioning_date,
           to: :result

  # Floored at 0 for display; the upper end is uncapped so an over-amortized
  # system shows its real degree (e.g. 150 %) instead of a misleading 100 %.
  def display_percent
    @display_percent ||= [result.degree_percent.to_f, 0].max.round
  end

  # The timeline needs both endpoints; without them (no break-even within the
  # period) only the bare degree is shown.
  def timeline?
    result.total_years.present?
  end

  # Today's position on the commissioning -> break-even axis, in percent. This
  # is the *time* elapsed, not the financial degree - the two run at different
  # speeds - and drives the "today" marker and the solid part of the track.
  # Fully elapsed once amortized.
  def elapsed_percent
    return 100 if amortized?

    span = (break_even_date - commissioning_date).to_f
    return 0 if span <= 0

    (((Date.current - commissioning_date) / span) * 100).clamp(0, 100).round
  end

  def start_label
    l(commissioning_date, format: '%B %Y')
  end

  def end_label
    l(break_even_date, format: '%B %Y')
  end

  def remaining_label
    t(
      '.remaining',
      duration: distance_of_time_in_words(Date.current, break_even_date),
    )
  end

  def total_label
    t('.total_years', total: number_with_precision(result.total_years, precision: 1))
  end
end
