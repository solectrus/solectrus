# The first row of the sheet (Insights::Component): the total of the
# period, named by what it is. An average is no total, and in a period
# that still runs, the total still grows.
class Insights::Total::Component < ViewComponent::Base
  def initialize(total:, running: false, average: false)
    super()
    @total = total
    @running = running
    @average = average
  end

  attr_reader :total

  def label
    if @average
      t('.average')
    elsif @running
      t('.so_far')
    else
      t('.total')
    end
  end
end
