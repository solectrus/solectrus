# Calculates the profitability of the PV system from the signed cash flow
# register (CashFlow) and the measured savings (sensor :savings), month by
# month for the past, projected with an average daily rate for the future
# (see SavingsSeries).
#
# Two perspectives are kept strictly separate:
#
# 1. Nominal: plain cumulative balance without any interest. Yields the
#    amortization degree, the nominal break-even and the nominal surplus.
# 2. Net present value (NPV): every monthly amount is discounted to the
#    simulation start with the calculatory interest rate r; the NPV is the
#    discounted balance at the end of the period (residual value 0).
#    Positive = the system beats an investment yielding r. The internal
#    rate of return (IRR) is the rate at which the NPV is exactly zero.
class AmortizationCalculator
  # Valid parameter ranges and defaults for the calculation. The controls
  # component, the controller and the MCP tool clamp user input into these
  # ranges via .clamp_period / .clamp_interest before computing.
  PERIOD_RANGE = 10..30
  public_constant :PERIOD_RANGE

  INTEREST_RANGE = 0.0..10.0
  public_constant :INTEREST_RANGE

  DEFAULT_PERIOD_YEARS = 20
  public_constant :DEFAULT_PERIOD_YEARS

  DEFAULT_INTEREST_RATE = 3.0 # % p. a.
  public_constant :DEFAULT_INTEREST_RATE

  # Coerce a raw (possibly nil, string or tampered) value to the default and
  # clamp it into the allowed range.
  def self.clamp_period(value)
    (value || DEFAULT_PERIOD_YEARS).to_i.clamp(PERIOD_RANGE)
  end

  def self.clamp_interest(value)
    (value || DEFAULT_INTEREST_RATE).to_f.clamp(INTEREST_RANGE)
  end

  def self.result(
    period_years: DEFAULT_PERIOD_YEARS,
    interest_rate: DEFAULT_INTEREST_RATE
  )
    key = cache_key(period_years:, interest_rate:)
    compute = -> { Rails.cache.fetch(key, expires_in: 1.day) { new(period_years:, interest_rate:).result } }
    compute.call
  rescue TypeError
    # A Result cached by an older app version may carry outdated struct
    # members (e.g. a renamed field), which raises on deserialization. Discard
    # the stale entry and recompute rather than failing the request.
    Rails.cache.delete(key)
    compute.call
  end

  # The result only changes with the calendar day (measured savings roll in
  # once per day), the cash flow register, or the two parameters. A
  # content-addressed key invalidates immediately on any of these edits
  # without an explicit sweep; the day component keeps a stale entry from
  # surviving past midnight and lets old keys expire on their own.
  def self.cache_key(period_years:, interest_rate:)
    [
      'amortization_calculator',
      Date.current,
      CashFlow.all.cache_key_with_version,
      period_years,
      interest_rate,
    ].join('/')
  end

  def initialize(
    period_years: DEFAULT_PERIOD_YEARS,
    interest_rate: DEFAULT_INTEREST_RATE
  )
    @period_years = period_years
    @interest_percent = interest_rate.to_f
    @interest_rate = @interest_percent / 100
  end

  attr_reader :period_years, :interest_rate

  def result
    nominal = nominal_series
    credits, debits = ledger_until_today
    table = yearly_table
    rows = table.to_a

    Result.new(
      degree_percent: categorization.degree_percent,
      break_even_date: break_even_date(nominal),
      installation_date: savings.effective_installation_date,
      net_position: credits - debits,
      gross_investment: categorization.gross_investment,
      investment_reduction: categorization.investment_reduction,
      net_investment: categorization.net_investment,
      operating_cashflow: categorization.operating_cashflow,
      # End-of-period figures come straight from the day-accurate engine, so
      # they match the table's last row and the chart's last point exactly.
      profit_nominal: table.profit_nominal,
      npv: table.npv,
      irr_percent: table.irr_percent,
      required_annual_savings: table.required_annual_savings,
      savings_per_day: savings.savings_per_day,
      savings_per_year: savings.savings_per_year,
      projection_uncertain: savings.projection_uncertain?,
      yearly_series: yearly_series(nominal, rows),
      yearly_table: rows,
      period_years:,
      interest_rate: @interest_percent,
    )
  end

  private

  def today
    @today ||= Date.current
  end

  def current_month
    @current_month ||= today.beginning_of_month
  end

  def savings
    @savings ||= SavingsSeries.new(today:)
  end

  def cash_flows
    @cash_flows ||=
      CashFlow
        .order(:date)
        .pluck(:date, :amount, :category)
        .map { |date, amount, category| [date, amount.to_f, category] }
  end

  # Classified figures (investment base, operating cash flow, degree) from the
  # flows booked up to today.
  def categorization
    @categorization ||= Categorization.new(cash_flows:, savings:, today:)
  end

  # Last day of the operating period: exactly period_years * 12 whole months
  # from the installation month. Anchoring on the month (not the day) keeps
  # the monthly bucket count exact - a day-based end floored to the month start
  # counted one bucket too many, stretching the period to 20.08 instead of an
  # even 20.0 years.
  def period_end_date
    @period_end_date ||=
      savings.installation_month + (period_years * 12).months - 1.day
  end

  def monthly
    @monthly ||= MonthlyAmounts.new(savings:, cash_flows:, period_end_date:)
  end

  # Plain cumulative balance at the end of each month, no interest:
  # [[month_start, balance], ...]
  def nominal_series
    balance = 0.0

    monthly.months.each_with_index.map do |month, index|
      [month, balance += monthly.amounts[index]]
    end
  end

  # Plain nominal ledger up to today: measured savings and positive flows as
  # credits, negative flows as debits. Future-dated flows are excluded.
  def ledger_until_today
    credits = savings.total_measured.to_f
    debits = 0.0

    cash_flows.each do |date, amount|
      next if date > today

      if amount.negative?
        debits += -amount
      else
        credits += amount
      end
    end

    [credits, debits]
  end

  # First month whose end balance reaches zero again after the balance has
  # been negative, linearly interpolated within the month. Months before the
  # first debit (e.g. savings accrued before the invoice was paid) are
  # skipped, so an initially positive balance does not count as break-even.
  def break_even_date(series)
    first_negative = series.index { |_month, balance| balance.negative? }
    return series.first&.first unless first_negative

    series[first_negative..].each_cons(2) do |(_, previous_balance), (month, balance)|
      next if balance.negative?

      fraction = previous_balance.abs / (balance - previous_balance)
      return month + (fraction * month.end_of_month.day).floor
    end

    nil
  end

  def yearly_series(nominal, rows)
    YearlySeries.new(
      nominal:,
      monthly:,
      savings:,
      current_month:,
      yearly_table: rows,
    ).to_a
  end

  # The day-accurate engine, memoized: the single source of the per-year figures
  # for the table (yearly_table.to_a), the chart (yearly_series) and the
  # discounting KPIs (npv, irr, required_annual_savings), so no view can diverge.
  def yearly_table
    @yearly_table ||=
      YearlyTable.new(
        savings:,
        cash_flows:,
        period_years:,
        today:,
        interest_rate:,
      )
  end
end
