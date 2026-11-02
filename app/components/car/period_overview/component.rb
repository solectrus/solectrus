# The overview of a period or a day of the car page: what the cars charged
# and what they drove, each as a card across the width (see
# Car::PeriodOverview::Card::Component), and below them the comparison with a
# combustion car as a bar. Both cards have one height and share the height
# of the page. Each figure of a period loads its chart beside the overview
# (see Car::ChartLink). A day has its timeline there.
#
# The charging and the driving fill it with their figures (see
# Car::PeriodOverview::Charging::Component and
# Car::PeriodOverview::Driving::Component). Without the driving, like for
# the guest or a car without an odometer, the card of the charging fills the
# overview alone, without the comparison.
#
# Without a report, the overview is the placeholder while the figures load,
# in the layout of the overview, so the page keeps its height.
class Car::PeriodOverview::Component < ViewComponent::Base
  # `all` is whether the page shows "all" and not one selected car.
  # `driving` is whether the selected cars drive (see Car::Section).
  def initialize(report: nil, all: false, driving: true)
    super()
    @report = report
    @all = all
    @driving = driving
  end

  attr_reader :report, :all

  def driving? = @driving
end
