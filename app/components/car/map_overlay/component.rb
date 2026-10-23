# A map that fills the window over the page, like a zoomed chart: the latest
# location of a car (see Car::Location::Component), and the map of a list
# below the car page (see Car::ListBox::Component). A link loads it into its
# frame, and the close button and ESC empty the frame again. So the map adds
# no page of its own.
class Car::MapOverlay::Component < ViewComponent::Base
  # The frame of the map, over the live view or over a list
  FRAME_ID = 'car_map'.freeze
  public_constant :FRAME_ID

  # `title` names the map in its head. Without it, the head shows the slot
  # `head`, like the badge of a car.
  def initialize(title: nil)
    super()
    @title = title
  end

  attr_reader :title

  renders_one :head
end
