class AmortizationCalculator
  # Cumulative measured savings per day, with O(log n) lookup.
  #
  # The IRR history evaluates the whole calculation on dozens of past dates, and
  # each of them asks for the measured total up to an arbitrary day - hundreds
  # of lookups in total. Summing the day hash per lookup would be O(days) every
  # time; a prefix sum over the sorted days turns each one into a binary search
  # instead, so the entire history costs a single savings query.
  class MeasuredSavings
    def initialize(by_day)
      @days = by_day.keys.sort
      running = 0.0
      @totals = @days.map { |day| running += by_day[day].to_f }
    end

    attr_reader :days

    # Sum of all measured days up to and including `date`.
    def total_until(date)
      index = (days.bsearch_index { |day| day > date } || days.size) - 1
      index.negative? ? 0.0 : @totals[index]
    end
  end
end
