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
  def self.result
    Rails.cache.fetch(cache_key, expires_in: 1.day) { new.result }
  end

  # The result only changes with the calendar day (measured savings roll in
  # once per day), the cash flow register, or the two parameters. A
  # content-addressed key invalidates immediately on any of these edits
  # without an explicit sweep; the day component keeps a stale entry from
  # surviving past midnight and lets old keys expire on their own.
  def self.cache_key
    [
      'amortization_calculator',
      Date.current,
      CashFlow.all.cache_key_with_version,
      Setting.amortization_period_years,
      Setting.amortization_interest_rate,
    ].join('/')
  end

  def initialize(
    period_years: Setting.amortization_period_years,
    interest_rate: Setting.amortization_interest_rate
  )
    @period_years = period_years
    @interest_rate = interest_rate.to_f / 100
  end

  attr_reader :period_years, :interest_rate

  def result
    nominal = nominal_series
    credits, debits = ledger_until_today

    Result.new(
      degree_percent: degree_percent(credits, debits),
      break_even_date: break_even_date(nominal),
      installation_date: savings.effective_installation_date,
      net_position: credits - debits,
      profit_nominal: nominal.last&.last,
      npv: discounting.npv_at(interest_rate),
      irr_percent: discounting.irr_percent,
      required_annual_savings:,
      savings_per_day: savings.savings_per_day,
      savings_per_year: savings.savings_per_year,
      projection_uncertain: savings.projection_uncertain?,
      yearly_series: yearly_series(nominal),
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
        .pluck(:date, :amount)
        .map { |date, amount| [date, amount.to_f] }
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

  def discounting
    @discounting ||= Discounting.new(amounts: monthly.amounts)
  end

  # Annual benefit needed so the NPV reaches zero at the given rate: the
  # negative NPV of the cash flows alone (without any savings), spread over
  # the period as a year-end annuity.
  def required_annual_savings
    flows_npv =
      cash_flows.sum do |date, amount|
        next 0.0 if date > period_end_date

        amount / Discounting.factor(interest_rate, monthly.index_of(date))
      end
    return unless flows_npv.negative?

    annuity_factor =
      (1..period_years).sum do |year|
        Discounting.factor(interest_rate, year * -12)
      end
    -flows_npv / annuity_factor
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

  def degree_percent(credits, debits)
    return if debits.zero?
    return unless savings.total_measured || credits.positive?

    credits.fdiv(debits) * 100
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

  # Points for the chart, anchored on the installation date rather than the
  # calendar: a leading anchor at the operating start (carrying the initial
  # investment, so the chart opens at its deepest point) followed by one point
  # per PV-year birthday - the balance after each whole 12-month block counted
  # from the installation month. Every segment thus spans a full year; the
  # first and last year no longer show a shallower slope from a partial
  # calendar year (see #5712). Months after the current one are projected.
  def yearly_series(nominal)
    balance_at = nominal.to_h
    installation_month = savings.installation_month
    first_month, first_balance = nominal.first

    entries = [
      yearly_entry(year: first_month.year, month: first_month, balance: first_balance),
    ]

    (1..period_years).each do |elapsed|
      month = installation_month + ((elapsed * 12) - 1).months
      entries << yearly_entry(
        year: installation_month.year + elapsed,
        month:,
        balance: balance_at[month],
      )
    end

    entries
  end

  def yearly_entry(year:, month:, balance:)
    {
      year:,
      nominal: balance,
      projected: month > current_month,
      degree: degree_by_month[month],
    }
  end

  # Cumulative nominal amortization degree (credits / debits * 100) at the end
  # of each month - the same measure as degree_percent, but as a running
  # series so the chart can show it per year. nil while no debit has been
  # booked yet.
  def degree_by_month
    @degree_by_month ||=
      begin
        cum_credits = 0.0
        cum_debits = 0.0

        monthly.months.index_with do |month|
          cum_credits += monthly.credits_in(month)
          cum_debits += monthly.debits_in(month)
          cum_debits.zero? ? nil : cum_credits.fdiv(cum_debits) * 100
        end
      end
  end
end
