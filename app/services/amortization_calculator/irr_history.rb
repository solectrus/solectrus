class AmortizationCalculator
  # Retrospective history of the internal rate of return: for a series of past
  # evaluation dates, the return the page would have shown on that very day -
  # measured savings up to then, projected forward from then over the same
  # operating period. It makes visible what the single headline figure hides:
  # how the outlook moved as savings accrued and payments were booked.
  #
  # Two deliberate cut-offs shape the curve:
  #
  # 1. Sampling starts only once a full year of measured data existed (the point
  #    where SavingsSeries stops flagging the projection as uncertain). Before
  #    that the projection rate is an all-time average over a few weeks, which
  #    swings the extrapolated return by tens of percent and would squash the
  #    meaningful part of the curve into a flat line at the top.
  # 2. Cash flows dated between an evaluation date and today are left out, so a
  #    repair appears as a step exactly when it happened instead of tilting the
  #    whole history downwards. Flows dated in the future are kept at every
  #    evaluation date - they are part of the plan throughout, which is what
  #    makes the last sample identical to the headline figure.
  class IrrHistory
    def initialize(savings:, cash_flows:, period_years:, today:)
      @savings = savings
      @cash_flows = cash_flows
      @period_years = period_years
      @today = today
    end

    attr_reader :savings, :cash_flows, :period_years, :today

    # [{ date:, irr_percent: }] in chronological order, empty while less than a
    # year of measured data exists. Dates without a zero crossing (only
    # outflows) are skipped rather than drawn as a gap.
    def to_a
      @to_a ||=
        sample_dates.filter_map do |date|
          irr_percent = irr_at(date)
          { date:, irr_percent: } if irr_percent
        end
    end

    private

    # The same engine the live figures come from, fed a past state: savings as
    # of the date and the flows known by then. The interest rate is irrelevant
    # here - the IRR is the rate that zeroes the NPV, found by bisection, so it
    # does not depend on the calculatory one.
    def irr_at(date)
      YearlyTable.new(
        savings: snapshot(date),
        cash_flows: cash_flows_until(date),
        period_years:,
        today: date,
        interest_rate: 0.0,
      ).irr_percent
    end

    def snapshot(date)
      SavingsSnapshot.new(measured:, installation_date:, today: date)
    end

    def measured
      @measured ||= MeasuredSavings.new(savings.measured_by_day)
    end

    def installation_date
      @installation_date ||= savings.effective_installation_date
    end

    def cash_flows_until(date)
      return cash_flows if date >= today

      cash_flows.reject do |flow_date, _amount, _category|
        flow_date > date && flow_date <= today
      end
    end

    # The first evaluable date, then every month end after it, then today -
    # fine enough to show when a payment moved the return, coarse enough to keep
    # the whole history at a few dozen recomputations.
    #
    # Sampling the first evaluable date explicitly (rather than starting at the
    # month end after it) matters twice: the band marking the not-yet-evaluable
    # period ends where it really ends instead of covering up to a month in
    # which the figure could in fact be stated, and a system that has just
    # passed its first year gets a curve right away instead of a lone point
    # until the month is out.
    def sample_dates
      return [] if first_date > today

      dates = [first_date]
      date = first_date.end_of_month
      while date < today
        dates << date
        date = date.next_month.end_of_month
      end

      # first_date can be a month end itself, and on the very day the first year
      # completes it is today - both would otherwise show up twice.
      (dates << today).uniq
    end

    # Earliest date with a full year of measured data behind it - measured_days
    # counts inclusively, so the year is complete one day before the
    # anniversary.
    def first_date
      @first_date ||= installation_date + SavingsSeries::DAYS_PER_YEAR - 1
    end
  end
end
