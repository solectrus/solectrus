class AmortizationCalculator
  # Measured savings from the summary table (month-by-month for the past)
  # plus the daily rate used to project the future.
  class SavingsSeries
    DAYS_PER_YEAR = 365
    private_constant :DAYS_PER_YEAR

    def initialize(today:)
      @today = today
    end

    attr_reader :today

    # Guard against the silent INSTALLATION_DATE fallback (2020-01-01):
    # clamp to the first day with measured data.
    def effective_commissioning_date
      @effective_commissioning_date ||=
        [
          Rails.configuration.x.installation_date,
          SummaryValue.minimum(:date),
        ].compact.max
    end

    def commissioning_month
      @commissioning_month ||= effective_commissioning_date.beginning_of_month
    end

    def measured_days
      @measured_days ||= (today - effective_commissioning_date).to_i + 1
    end

    # Measured savings of the given month, nil if there is no data (or the
    # month is outside the measured range). The current month is partial.
    def measured_for(month)
      return unless month.between?(commissioning_month, current_month)

      measured_by_month[month]
    end

    # Savings attributable to the given month: fully measured for past
    # months, measured plus a projection for the remaining days of the
    # current month, and a pure projection for future months.
    def savings_for(month)
      if month < current_month
        measured_for(month) || 0.0
      elsif month == current_month
        remaining_days = month.end_of_month.day - today.day
        (measured_for(month) || 0.0) + (daily_projection_rate.to_f * remaining_days)
      else
        daily_projection_rate.to_f * month.end_of_month.day
      end
    end

    def total_measured
      @total_measured ||= measured_by_month.values.compact.presence&.sum
    end

    # Rolling year captures seasonality and system changes (e.g. a heat pump
    # added later); with less than a year of data fall back to the all-time
    # average and flag the prognosis as uncertain.
    def projection_uncertain?
      measured_days < DAYS_PER_YEAR
    end

    def daily_projection_rate
      @daily_projection_rate ||=
        if !projection_uncertain? && rolling_year_savings
          rolling_year_savings.fdiv(DAYS_PER_YEAR)
        else
          all_time_savings_per_day
        end
    end

    # Average daily savings of the projection basis: the rolling year when a
    # full year of data exists, the all-time average otherwise. Same basis as
    # savings_per_year (= savings_per_day * DAYS_PER_YEAR), so the "per day" and
    # "per year" figures stay consistent instead of mixing rolling year and
    # all-time.
    def savings_per_day
      daily_projection_rate
    end

    def savings_per_year
      return unless daily_projection_rate

      daily_projection_rate * DAYS_PER_YEAR
    end

    private

    # All-time average since commissioning - the fallback projection rate while
    # less than a full year of measured data is available.
    def all_time_savings_per_day
      return unless total_measured && measured_days.positive?

      total_measured.fdiv(measured_days)
    end

    def current_month
      @current_month ||= today.beginning_of_month
    end

    def measured_by_month
      @measured_by_month ||= query_savings(measured_timeframe, group_by: :month)
    end

    # Timeframe spanning commissioning up to today. With only a single day of
    # measured data (commissioning == today) a range would be same-day, which
    # Timeframe rejects, so query that single day directly.
    def measured_timeframe
      if effective_commissioning_date < today
        Timeframe.new("#{effective_commissioning_date}..#{today}")
      else
        Timeframe.new(today.to_s)
      end
    end

    # Last 365 completed days, ending yesterday - identical to the P365D
    # timeframe of the savings balance page, so the "annual benefit" tile can
    # link to a page showing the same figure. Excluding the partial current day
    # also keeps it from skewing the projection rate.
    def rolling_year_savings
      @rolling_year_savings ||=
        query_savings(Timeframe.new("#{today - DAYS_PER_YEAR}..#{today - 1}"))
    end

    def query_savings(timeframe, group_by: nil)
      Sensor::Query::Total.new(timeframe) do |q|
        q.sum :savings, :sum
        q.group_by group_by if group_by
      end.call.savings
    end
  end
end
