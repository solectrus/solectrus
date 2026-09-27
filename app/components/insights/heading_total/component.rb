# The right side of the heading of the sheet (insights/index.html.slim): the
# total of the period. In a period that still runs, the total still grows, so
# "so far" stands before it.
class Insights::HeadingTotal::Component < ViewComponent::Base
  def initialize(total:, running: false)
    super()
    @total = total
    @running = running
  end

  attr_reader :total

  def running?
    @running
  end
end
