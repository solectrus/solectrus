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

  # `label` names the card. `time` is the time of the latest reading, or nil.
  # A car shows the age of its reading in its card instead. `css_class` adds
  # to the card, like its width, and `data` its data attributes.
  def initialize(label:, time: nil, css_class: nil, data: {})
    super()
    @label = label
    @time = time
    @css_class = css_class
    @data = data
  end

  attr_reader :label, :time, :css_class, :data
end
