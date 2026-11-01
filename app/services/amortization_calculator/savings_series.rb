class AmortizationCalculator
  # Measured savings from the summary table (month-by-month for the past)
  # plus the daily rate used to project the future.
  class SavingsSeries
    def initialize(today:)
      @today = today
    end

    attr_reader :today

    # How long the system has been measuring - the age of the data is a fact of
    # its own (MeasuredRange), shared with the snapshots and the page.
    def measured_range
      @measured_range ||= MeasuredRange.new(today:)
    end

    def effective_installation_date = measured_range.installation_date

    def measured_days = measured_range.days

    def installation_month
      @installation_month ||= effective_installation_date.beginning_of_month
    end

    # Measured savings of the given month, nil if there is no data (or the
    # month is outside the measured range). The current month is partial.
    def measured_for(month)
      return unless month.between?(installation_month, current_month)

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

    # Savings attributable to an inclusive day range: measured for past days,
    # projected (daily rate) for days after today, mixed for a range straddling
    # today. Used by the yearly table, whose PV years are day-accurate (anchored
    # on the installation date), so the figure matches the range it links to.
    def savings_in_range(from, to)
      return 0.0 if to < from

      savings_until(to) - savings_until(from.prev_day)
    end

    # Rolling year captures seasonality and system changes (e.g. a heat pump
    # added later); with less than a year of data fall back to the all-time
    # average and flag the prognosis as uncertain.
    def projection_uncertain? = !measured_range.full_year?

    def daily_projection_rate
      @daily_projection_rate ||=
        if !projection_uncertain? && rolling_year_savings
          rolling_year_savings.fdiv(365)
        else
          all_time_savings_per_day
        end
    end

    # Average daily savings of the projection basis: the rolling year when a
    # full year of data exists, the all-time average otherwise. Same basis as
    # savings_per_year (= savings_per_day * 365), so the "per day" and
    # "per year" figures stay consistent instead of mixing rolling year and
    # all-time.
    def savings_per_day
      daily_projection_rate
    end

    def savings_per_year
      return unless daily_projection_rate

      daily_projection_rate * 365
    end

    # Measured savings per day since installation - the only query of the
    # series. The months, the rolling year and the IRR history all derive from
    # it, so replaying the calculation on dozens of past dates costs no further
    # query.
    def measured_by_day
      @measured_by_day ||= query_savings(measured_timeframe, group_by: :day)
    end

    # The daily savings summed up to any day, see MeasuredSavings
    def measured_savings
      @measured_savings ||= MeasuredSavings.new(measured_by_day)
    end

    private

    # All-time average since installation - the fallback projection rate while
    # less than a full year of measured data is available.
    def all_time_savings_per_day
      return unless total_measured && measured_days.positive?

      total_measured.fdiv(measured_days)
    end

    def current_month
      @current_month ||= today.beginning_of_month
    end

    # A month without any measured day has no entry
    def measured_by_month
      @measured_by_month ||=
        measured_by_day.each_with_object({}) do |(day, value), months|
          next if value.nil?

          month = day.beginning_of_month
          months[month] = months.fetch(month, 0.0) + value
        end
    end

    # Cumulative measured savings from installation up to (and including) the
    # given day, capped at today; days without a summary contribute nothing.
    def savings_until(date)
      return 0.0 if date < effective_installation_date

      measured = measured_until([date, today].min)
      future_days = date > today ? (date - today).to_i : 0

      measured + (daily_projection_rate.to_f * future_days)
    end

    def measured_until(date)
      measured_savings.total_until(date)
    end

    # Timeframe spanning installation up to today. With only a single day of
    # measured data (installation == today) a range would be same-day, which
    # Timeframe rejects, so query that single day directly.
    def measured_timeframe
      if effective_installation_date < today
        Timeframe.new("#{effective_installation_date}..#{today}")
      else
        Timeframe.new(today.to_s)
      end
    end

    # Last 365 completed days, ending yesterday - identical to the P365D
    # timeframe of the savings balance page, so the "annual benefit" tile can
    # link to a page showing the same figure. Excluding the partial current day
    # also keeps it from skewing the projection rate.
    #
    # Read only with a full year of data, so the window lies within the days
    # of measured_by_day. nil when none of its days has a value.
    def rolling_year_savings
      @rolling_year_savings ||=
        begin
          from = today - 365.days
          to = today - 1.day
          values = measured_by_day.filter_map { |day, value| value if day.between?(from, to) }
          values.sum if values.any?
        end
    end

    def query_savings(timeframe, group_by: nil)
      Sensor::Query::Total.new(timeframe) do |q|
        q.sum :savings, :sum
        q.group_by group_by if group_by
      end.call.savings
    end
  end
end
