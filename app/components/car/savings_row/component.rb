# The savings against a combustion car on the car page, in a row over the
# width of both columns between their figures and their charts, because
# the savings set the charging against the driving. A tap opens the
# comparison of the timeframe. The page knows the place of the row before
# the figures load (see Car::Report#savings?), so the row stays also
# without a compared distance. It shows a dash then, and the comparison
# tells why.
class Car::SavingsRow::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # Without `report`, the row keeps its place while the figures load
  def initialize(report: nil)
    super()
    @report = report
  end

  attr_reader :report

  def href
    return unless report

    timeframe = report.timeframe
    helpers.cars_savings_path(timeframe: (timeframe.to_param unless timeframe.all?), car: report.car&.id)
  end

  # The savings like on the comparison page, green for a gain and red for
  # a loss
  def value
    return Car::OverviewBox::Component.skeleton('w-12') unless report
    return '–' unless report.comparison.ready?

    amounts = Car::ComparisonAmounts.new(report.comparison)
    savings = amounts.savings
    helpers.tag.span(money(savings, precision: amounts.precision), class: savings_color_of(savings))
  end
end
