# The comparison with a combustion car below the overview of a period of
# the car page (see Car::PeriodOverview::Component): a bar of the cost of
# the car and its savings (see
# Car::PeriodOverview::Driving::Savings#comparison). It opens the comparison
# page, and its tooltip names the costs of both cars.
class Car::PeriodOverview::Comparison::Component < ViewComponent::Base
  include Car::FigureTag

  # `figure` is a Car::Figure whose value is a Car::ShareBar::Component
  def initialize(figure:, timeframe:)
    super()
    @figure = figure
    @timeframe = timeframe
  end

  attr_reader :figure, :timeframe

  def call
    figure_tag(figure, class: 'block shrink-0 rounded-xl focus-ring', link_class: 'lg:hover:brightness-95') do
      safe_join([render(figure.value), (render(tooltip(figure)) if figure.tooltip?)])
    end
  end
end
