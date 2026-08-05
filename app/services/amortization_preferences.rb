# What this browser wants the calculation to assume - operating period and
# calculatory interest rate - as one request supplies them: from the slider form
# when a slider was just moved, otherwise from the cookie the last change left
# behind, otherwise the defaults.
#
# Which values are allowed is not decided here: both are clamped into the ranges
# AmortizationCalculator allows, which is also what disarms a tampered cookie -
# whatever it claims, only a valid parameter pair ever reaches the calculation.
class AmortizationPreferences
  # Both values live in one JSON object under this cookie, so a single
  # permanent cookie carries the whole setting. The name is a wire format that
  # is already out there - renaming it would reset everyone's sliders.
  COOKIE_NAME = :amortization_params
  public_constant :COOKIE_NAME

  def initialize(submitted: {}, cookie: nil)
    @submitted = submitted
    @cookie = cookie
  end

  def period_years
    @period_years ||=
      AmortizationCalculator.clamp_period(stored('period_years'))
  end

  def interest_rate
    @interest_rate ||=
      AmortizationCalculator.clamp_interest(stored('interest_rate'))
  end

  # Whether this browser already carries a setting of its own. The caller
  # refreshes the expiry of an existing cookie on every visit, but does not hand
  # one to everybody who just looks at the defaults.
  def customized?
    cookie_params.present?
  end

  # The effective values, for writing back into the cookie.
  def to_h
    { period_years:, interest_rate: }
  end

  private

  attr_reader :submitted, :cookie

  def stored(name)
    submitted[name].presence || cookie_params[name]
  end

  # An absent or malformed cookie is simply no cookie at all - it falls back to
  # the defaults rather than failing the request.
  def cookie_params
    @cookie_params ||=
      begin
        parsed = JSON.parse(cookie.to_s)
        parsed.is_a?(Hash) ? parsed : {}
      rescue JSON::ParserError
        {}
      end
  end
end
