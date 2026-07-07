class AmortizationCalculator
  # The day-accurate engine of the whole calculation: it builds the per-year
  # table rows AND the discounting KPIs (net present value, internal rate of
  # return, required annual savings), so the table, the chart and the headline
  # figures all rest on one basis and cannot diverge.
  #
  # PV years are anchored on the exact installation DATE (not the calendar year,
  # and not rounded to whole months): PV year N runs from the (N-1)th
  # installation anniversary to the day before the Nth, so year 1 starts on the
  # installation date itself. Each row carries the year's measured/projected
  # sensor savings, its cash flows summed per category, the cumulative nominal
  # balance, the cumulative net present value (discounted twin of the nominal
  # balance), the cumulative amortization degree and its exact date range - so
  # the savings figure links to precisely the days it covers. The balance is a
  # displayed euro figure, so it accumulates whole-euro amounts (each cash-flow
  # entry and the year's savings rounded); the (rounded) savings plus the sum of
  # all (rounded) category flows equals the balance change, so the table's
  # columns foot to the balance to the euro.
  #
  # Discounting is day-accurate too: cash flows are discounted by their exact
  # date (an investment at t=0 is barely discounted), each PV year's savings at
  # its mid-point (they accrue throughout the year). At a 0% rate every factor
  # is 1, so the discounted column equals the nominal balance and the npv equals
  # the nominal surplus.
  class YearlyTable
    def initialize(savings:, cash_flows:, period_years:, today:, interest_rate:)
      @savings = savings
      @cash_flows = cash_flows
      @period_years = period_years
      @today = today
      @interest_rate = interest_rate
    end

    attr_reader :savings, :cash_flows, :period_years, :today, :interest_rate

    def to_a
      @to_a ||=
        begin
          discounted = 0.0

          breakdown.map do |year|
            discounted += present_value(year, interest_rate)

            {
              nominal: year[:nominal],
              # Discounted twin of the nominal balance: the same cash flows and
              # savings, discounted to the operating start. At a 0% rate it
              # equals nominal; the last row is the net present value (KPI).
              npv: discounted,
              savings: year[:savings],
              flows: year[:flows].reject { |_category, amount| amount.zero? },
              degree: year[:degree],
              projected: year[:projected],
              period: year[:period],
              drilldown_from: year[:drilldown_from],
            }
          end
        end
    end

    # Nominal surplus at the end of the period, without interest - the last
    # row's cumulative balance (also the chart's last point).
    def profit_nominal
      breakdown.last[:nominal]
    end

    # Net present value of the whole period at the calculation's rate: the last
    # row's cumulative discounted balance, so the KPI and the table's last cell
    # are the identical value (period_years >= 10, so there is always a row).
    def npv
      to_a.last[:npv]
    end

    # Internal rate of return in % p.a.: the rate at which the NPV is zero, found
    # by bisection. nil when there is no sign change in the searched range (only
    # outflows or only inflows).
    def irr_percent
      low = -0.9
      high = 10.0
      return unless npv_at(low).positive? && npv_at(high).negative?

      40.times do
        mid = (low + high) / 2
        npv_at(mid).positive? ? low = mid : high = mid
      end

      (low + high) / 2 * 100
    end

    # Level annual benefit needed for a non-negative NPV: the negative present
    # value of the cash flows alone, spread over the period as a mid-year annuity
    # (the same timing the actual savings are discounted with). nil unless the
    # flows are a net outflow.
    def required_annual_savings
      flows_pv = flows_present_value(interest_rate)
      return unless flows_pv.negative?

      -flows_pv / annuity_factor(interest_rate)
    end

    private

    def npv_at(rate)
      breakdown.sum { |year| present_value(year, rate) }
    end

    # Present value of one PV year: its savings at the year's mid-point plus each
    # of its cash flows at that flow's exact date. Both are discounted on the
    # same whole-euro basis as the nominal balance (savings rounded per year, the
    # cash-flow entries already rounded), so at a 0% rate the discounted column
    # equals the nominal balance to the euro.
    def present_value(year, rate)
      discount_savings(year[:savings].round, year[:elapsed], rate) +
        flows_present_value_of(year, rate)
    end

    def flows_present_value(rate)
      breakdown.sum { |year| flows_present_value_of(year, rate) }
    end

    # Present value of a single PV year's cash flows, each discounted by its
    # exact date.
    def flows_present_value_of(year, rate)
      year[:entries].sum { |date, amount, _category| discount_flow(amount, date, rate) }
    end

    def annuity_factor(rate)
      (1..period_years).sum do |elapsed|
        1.0 / Discounting.factor(rate, (elapsed - 0.5) * 12)
      end
    end

    # Savings accrue throughout the year, so a PV year's savings are discounted
    # at its mid-point (t = elapsed - 0.5 years).
    def discount_savings(savings, elapsed, rate)
      savings / Discounting.factor(rate, (elapsed - 0.5) * 12)
    end

    # A cash flow is discounted by its exact date. Anything dated on or before
    # the operating start sits at t=0 (factor 1) - a down payment is not
    # compounded forward.
    def discount_flow(amount, date, rate)
      years = [(date - installation_date).to_f / 365.25, 0.0].max
      amount / Discounting.factor(rate, years * 12)
    end

    # Rate-independent per-year figures: the savings, the raw cash flow entries
    # in the year's window and their per-category sums, plus the cumulative
    # nominal balance, amortization degree, projection flag and date range.
    def breakdown
      @breakdown ||=
        begin
          balance = 0.0
          operating = 0.0
          net_investment = 0.0

          (1..period_years).map do |elapsed|
            starts_on = installation_date + (elapsed - 1).years
            ends_on = installation_date + elapsed.years - 1.day
            year_savings = savings_for_year(starts_on, ends_on)
            # Year 1 also absorbs anything booked before the operating start
            # (e.g. a down payment), so it has no lower bound; every later year
            # takes just its own window. The same bound drives the table's
            # drill-down link, so it travels with the row.
            from = elapsed == 1 ? nil : starts_on
            entries = entries_for(from, ends_on)
            flows = aggregate(entries)

            # The euro balance is a displayed figure, so it is kept in whole
            # euros: rounding each cash-flow entry and the year's savings before
            # they accumulate makes the table's rounded columns foot to the
            # rounded balance exactly, and the chart (which reads this same
            # nominal) can't drift a euro from the table. The savings sensor
            # reading stays raw in the row (for the projection and the degree
            # ratio); only its contribution to the balance is rounded.
            balance += year_savings.round + flows.values.sum
            operating += year_savings + total_in(flows, CashFlow::OPERATING_CATEGORIES)
            net_investment -= total_in(flows, CashFlow::INVESTMENT_BASE_CATEGORIES)

            {
              elapsed:,
              savings: year_savings,
              entries:,
              flows:,
              nominal: balance,
              degree: degree(operating, net_investment),
              projected: ends_on > today,
              period: starts_on..ends_on,
              drilldown_from: from,
            }
          end
        end
    end

    # Sensor savings attributable to a PV year. A year still in the past or
    # straddling today is taken day-accurately (measured, blended for the
    # transition year). A year lying entirely in the future uses the constant
    # annual projection instead of the day-accurate range, so the expected
    # savings don't wobble by a day between leap years (365 vs 366 days).
    def savings_for_year(starts_on, ends_on)
      if starts_on > today
        savings.savings_per_year.to_f
      else
        savings.savings_in_range(starts_on, ends_on)
      end
    end

    def installation_date
      @installation_date ||= savings.effective_installation_date
    end

    # Cash flow entries in the row's window [from, to], each amount rounded to a
    # whole euro. An open lower bound (from nil, year 1) also pulls in anything
    # dated before the operating start. Rounding here is the single source of the
    # whole-euro basis: the per-category sums (#aggregate), the nominal balance
    # and the discounting all read these rounded amounts, so they stay mutually
    # consistent - the discounted column still equals the nominal balance at 0%.
    def entries_for(from, to)
      cash_flows.filter_map do |date, amount, category|
        [date, amount.round, category] if date <= to && (from.nil? || date >= from)
      end
    end

    def aggregate(entries)
      entries.each_with_object(Hash.new(0.0)) do |(_date, amount, category), totals|
        totals[category] += amount
      end
    end

    def degree(operating, net_investment)
      return unless net_investment.positive?

      operating.fdiv(net_investment) * 100
    end

    def total_in(flows, categories)
      flows.sum { |category, amount| categories.include?(category) ? amount : 0.0 }
    end
  end
end
