class AmortizationCalculator
  # The measured savings as they stood on a past day: the same daily readings,
  # but evaluated as if that day were today - measured up to it, projected
  # afterwards from the projection rate that was current back then.
  #
  # It mirrors exactly the part of SavingsSeries the YearlyTable consumes
  # (installation date, projection rate, savings of a day range), so a past
  # state can be fed into the very same engine. Unlike SavingsSeries it never
  # touches the database: every snapshot reads from the shared prefix-summed
  # daily series, which is what makes evaluating dozens of dates affordable.
  class SavingsSnapshot
    DAYS_PER_YEAR = SavingsSeries::DAYS_PER_YEAR
    private_constant :DAYS_PER_YEAR

    def initialize(measured:, installation_date:, today:)
      @measured = measured
      @installation_date = installation_date
      @today = today
    end

    attr_reader :measured, :today

    def effective_installation_date
      @installation_date
    end

    def measured_days
      (today - effective_installation_date).to_i + 1
    end

    def projection_uncertain?
      measured_days < DAYS_PER_YEAR
    end

    # Savings attributable to an inclusive day range: measured for days up to
    # the snapshot day, projected for days after it - the same rule
    # SavingsSeries applies to the live calculation.
    def savings_in_range(from, to)
      return 0.0 if to < from

      savings_until(to) - savings_until(from.prev_day)
    end

    def savings_per_year
      daily_projection_rate * DAYS_PER_YEAR
    end

    # Rolling year once a full year of data has accrued, all-time average
    # before that - identical to SavingsSeries#daily_projection_rate, just
    # derived from the daily series instead of its own queries.
    def daily_projection_rate
      @daily_projection_rate ||=
        if projection_uncertain?
          measured.total_until(today) / measured_days
        else
          rolling_year_savings.fdiv(DAYS_PER_YEAR)
        end
    end

    private

    # Last 365 completed days, ending the day before the snapshot day - the
    # same window the live projection uses.
    def rolling_year_savings
      measured.total_until(today - 1) -
        measured.total_until(today - 1 - DAYS_PER_YEAR)
    end

    def savings_until(date)
      return 0.0 if date < effective_installation_date

      future_days = date > today ? (date - today).to_i : 0

      measured.total_until([date, today].min) +
        (daily_projection_rate * future_days)
    end
  end
end
