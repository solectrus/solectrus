# The right side of the heading of the sheet (insights/index.html.slim): the
# total of the period. In a period that still runs, the total still grows, so
# "so far" stands before it.
class Insights::HeadingTotal::Component < ViewComponent::Base
  # An `average` is no total, so the sign of the average stands before it
  # instead
  def initialize(total:, running: false, average: false)
    super()
    @total = total
    @running = running
    @average = average
  end

  attr_reader :total

  def running?
    @running
  end

  def average?
    @average
  end
end
