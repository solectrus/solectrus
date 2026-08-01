# Line chart of how the internal rate of return has moved over time: for each
# past evaluation date, the return the calculation would have yielded on that
# very day. The "return p.a." KPI of the chart view is the last point of this
# curve - here it gains the context of where it came from.
#
# The discount rate is drawn as a bare dashed level, and nothing else on the
# chart reacts to it: the return is the rate that zeroes the net present value
# and is therefore independent of the calculatory one. Tinting the curve against
# it made a figure that provably does not move look as if it had changed.
#
# The axis spans the full operating time from the installation on, while the
# curve only sets in a year later (before that there is no evaluable data). The
# leading gap is the point: it shows how much of the system's life the figure
# could not yet be stated for, instead of pretending the history starts there.
class AmortizationReturnChart::Component < ViewComponent::Base
  # Shape of the round chart controls, matching the other charts. The cursor is
  # left out so both users of it can set their own: the buttons are clickable,
  # the info icon is only a hover target.
  ICON_BUTTON_SHAPE =
    'flex items-center justify-center p-2 font-medium focus:outline-none ' \
    'focus:ring-2 focus:ring-gray-700 dark:focus:ring-gray-400 text-sm gap-2 ' \
    'hover:bg-gray-200 dark:hover:bg-gray-700 bg-gray-100 dark:bg-gray-800 ' \
    'rounded-full size-8 border border-gray-300 dark:border-gray-600'.freeze
  private_constant :ICON_BUTTON_SHAPE

  ICON_BUTTON_CLASS = "#{ICON_BUTTON_SHAPE} cursor-pointer".freeze
  private_constant :ICON_BUTTON_CLASS

  def initialize(result:)
    super()
    @result = result
  end

  attr_reader :result

  # The info icon sits in the same row as the maximize button, so it takes the
  # same round shape and inherits the icon color from the container - a small
  # muted glyph next to a full-size button reads as an afterthought.
  def info_icon_class
    ICON_BUTTON_SHAPE
  end

  delegate :irr_history,
           :interest_rate,
           :period_years,
           :installation_date,
           to: :result

  # The level the dashed line is drawn at. Bare, without a caption: the figure
  # itself is on the slider in the sub-navigation, so repeating it on the canvas
  # would only add noise.
  def chart_rate
    interest_rate.round(1)
  end

  # The history needs a full year of measured data before it says anything; up
  # to then the view shows a hint instead of an empty canvas.
  #
  # A lone sample does not count either: on the very day the first year
  # completes, first evaluable date and today coincide, and the chart would be
  # one dot on an axis auto-scaled to a meaningless half-percent band around it.
  # That lasts a single day, after which there is a real segment to draw.
  def history?
    irr_history.size > 1
  end

  def chart_data
    {
      points:
        irr_history.map do |entry|
          { x: entry[:date].iso8601, y: entry[:irr_percent].round(2) }
        end,
      rate: chart_rate,
      # Left edge of the axis: the operating start, not the first sample.
      start: installation_date&.iso8601,
    }
  end

  # Date span the axis covers, shown as the fullscreen subtitle (like the
  # timeframe on the other charts), e.g. "2020 - 2026".
  def period_label
    return unless history?

    first = (installation_date || irr_history.first[:date]).year
    last = irr_history.last[:date].year
    first == last ? first.to_s : "#{first} – #{last}"
  end

  # Behind the info icon, one paragraph each: what the curve is (and what it is
  # not), why it swings as far as it does, the limitation its shape can
  # otherwise be misread as (only the savings are extrapolated), and what the
  # dashed level means - kept separate because it is the only thing on the chart
  # the sliders move.
  def hint
    [
      t('.hint_what', years: period_years),
      t('.hint_volatility'),
      t('.hint_limits'),
      t('.hint_reference'),
    ].join("\n\n")
  end
end
