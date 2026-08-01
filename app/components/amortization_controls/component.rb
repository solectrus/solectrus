# Slider controls (shown to every visitor who may see the calculation) to
# adjust the two calculation parameters - duration and calculatory interest
# rate - directly on the amortization page. Releasing a slider auto-submits the
# form via Turbo, which recomputes and re-renders the detail frame with the
# given parameters and remembers them in a per-browser cookie (not a global
# Setting), so the next page load renders the same result server-side.
class AmortizationControls::Component < ViewComponent::Base
  # The parameter ranges are domain facts owned by AmortizationCalculator; the
  # slider granularity is a view concern and stays here.
  PERIOD_RANGE = AmortizationCalculator::PERIOD_RANGE
  INTEREST_RANGE = AmortizationCalculator::INTEREST_RANGE
  INTEREST_STEP = 0.1
  private_constant :PERIOD_RANGE
  private_constant :INTEREST_RANGE
  private_constant :INTEREST_STEP

  # variant: :panel renders for a light dropdown (mobile), :bar renders compact
  # with light text for the indigo sub-navigation bar (desktop, inline).
  def initialize(result:, view: :chart, variant: :panel)
    super()
    @result = result
    @view = view
    @variant = variant
  end

  attr_reader :result, :view, :variant

  delegate :interest_rate, to: :result

  # Echoed back on submit so the update action re-renders the same view the
  # sliders were adjusted on. The chart is the default, so it needs no field.
  def echoed_view
    view.to_s if view != :chart
  end

  def bar?
    variant == :bar
  end

  # The bar variant sits on the indigo sub-nav (light-on-indigo in both themes),
  # so its slider needs a light track/thumb instead of the panel's dark-on-light
  # treatment - see the .range-slider--bar rules.
  def slider_class
    ['range-slider w-full', ('range-slider--bar' if bar?)].compact.join(' ')
  end

  # Both sliders side by side and width-capped on the bar; a two-column grid
  # filling the dropdown panel otherwise.
  def wrapper_class
    bar? ? 'flex items-end gap-5' : 'grid grid-cols-2 gap-x-6 lg:gap-x-16 gap-y-3'
  end

  # Keep each slider narrow enough to sit next to the tabs in the bar.
  def control_class
    bar? ? 'w-40' : ''
  end

  # Muted caption on both, but light on the indigo bar.
  def caption_class
    bar? ? 'text-gray-300 dark:text-gray-400' : 'text-gray-600 dark:text-gray-400'
  end

  # The value reads white on the indigo bar, dark on the light panel. In dark
  # mode the bar is dimmed to gray-300 so the white is not glaring on indigo-900.
  def value_class
    bar? ? 'text-white dark:text-gray-300' : 'text-gray-800 dark:text-gray-100'
  end

  # Clamped to the effective range so the slider thumb and the value label
  # agree even when the requested period is below the current minimum.
  def period_years
    result.period_years.clamp(period_min, period_max)
  end

  def rate_label
    number_with_precision(interest_rate, precision: 1)
  end

  # The period must not end in the past, so the slider minimum rises with the
  # system's age: it is the smallest whole number of years reaching at least
  # today, bounded by PERIOD_RANGE. A system running for 12+ years therefore
  # cannot be evaluated with a period below 12.
  def period_min
    minimum_operating_years.clamp(PERIOD_RANGE.min, PERIOD_RANGE.max)
  end

  def period_max = PERIOD_RANGE.max
  def interest_min = INTEREST_RANGE.min
  def interest_max = INTEREST_RANGE.max
  def interest_step = INTEREST_STEP

  private

  def minimum_operating_years
    date = Rails.configuration.x.installation_date
    years = Date.current.year - date.year
    years += 1 if date + years.years < Date.current
    years
  end
end
