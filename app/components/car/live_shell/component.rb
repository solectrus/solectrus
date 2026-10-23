# The card of the live view of the car page (see Car::LiveView::Component): a
# head with the title and the time of the latest reading, and the content
# below. A car has one (see Car::LiveCard::Component), and so has the power
# of the wallbox for a charge of no car.
class Car::LiveShell::Component < ViewComponent::Base
  # A card stands on the white page without a ground or a frame of its own
  CARD = 'flex flex-col min-w-0 min-h-0 rounded-2xl'.freeze
  public_constant :CARD

  # The title of the head, like the name of a car in its color
  renders_one :title

  # `label` names the card. `time` is the time of the latest reading, or nil,
  # and `time_title` its tooltip. `css_class` adds to the card, like its width.
  def initialize(label:, time: nil, time_title: nil, css_class: nil)
    super()
    @label = label
    @time = time
    @time_title = time_title
    @css_class = css_class
  end

  attr_reader :label, :time, :time_title, :css_class
end
