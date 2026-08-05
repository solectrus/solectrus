# Slider controls (shown to every visitor who may see the calculation) to
# adjust the two calculation parameters - duration and calculatory interest
# rate - directly on the amortization page. Releasing a slider auto-submits the
# form via Turbo, which recomputes and re-renders the detail frame with the
# given parameters and remembers them in a per-browser cookie (not a global
# Setting), so the next page load renders the same result server-side.
class AmortizationControls::Component < ViewComponent::Base
  # The parameter ranges are domain facts owned by AmortizationCalculator; the
  # slider granularity is a view concern and stays here.
  INTEREST_RANGE = AmortizationCalculator::INTEREST_RANGE
  INTEREST_STEP = 0.1
  private_constant :INTEREST_RANGE
  private_constant :INTEREST_STEP

  # variant: :panel renders for a light dropdown (mobile), :bar renders compact
  # with light text for the indigo sub-navigation bar (desktop, inline).
  def initialize(period_years:, interest_rate:, view: :chart, variant: :panel)
    super()
    # Clamped like at every other entry point, so thumb and label agree even if
    # a caller hands in a period the calculation would not accept - the minimum
    # rises with the system's age (see AmortizationCalculator.period_range).
    @period_years = AmortizationCalculator.clamp_period(period_years)
    @interest_rate = interest_rate
    @view = view
    @variant = variant
  end

  attr_reader :period_years, :interest_rate, :view, :variant

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

  def rate_label
    number_with_precision(interest_rate, precision: 1)
  end

  # The slider offers exactly the periods the calculation accepts - including
  # the minimum that rises with the system's age, so thumb and computed value
  # cannot drift apart.
  def period_min = period_range.min
  def period_max = period_range.max
  def interest_min = INTEREST_RANGE.min
  def interest_max = INTEREST_RANGE.max
  def interest_step = INTEREST_STEP

  private

  def period_range = @period_range ||= AmortizationCalculator.period_range
end
