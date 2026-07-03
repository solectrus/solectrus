# Slider controls (admin + sponsor only) to adjust the two calculation
# parameters - duration and calculatory interest rate - directly on the
# amortization page. Releasing a slider auto-submits the form via Turbo,
# which persists the value in Setting and re-renders the detail frame.
class AmortizationControls::Component < ViewComponent::Base
  PERIOD_RANGE = 10..30
  INTEREST_RANGE = 0.0..10.0
  INTEREST_STEP = 0.1
  public_constant :PERIOD_RANGE
  public_constant :INTEREST_RANGE
  private_constant :INTEREST_STEP

  # Clamped to the effective range so the slider thumb and the value label
  # agree even when a previously stored setting is below the current minimum.
  def period_years
    Setting.amortization_period_years.clamp(period_min, period_max)
  end

  def interest_rate
    Setting.amortization_interest_rate
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
