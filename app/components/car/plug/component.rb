# The plug of the wallbox or of a car: an icon and whether a car is
# connected. The full plug gives the text, and the caller gives the frame,
# for example a pill. The compact plug is the icon alone, and its tooltip
# gives the text.
class Car::Plug::Component < ViewComponent::Base
  def initialize(connected:, compact: false)
    super()
    @connected = connected
    @compact = compact
  end

  attr_reader :connected

  def compact? = @compact

  def render?
    !connected.nil?
  end

  def label
    t(connected ? 'sensors.wallbox_car_connected_short' : 'sensors.wallbox_car_disconnected_short')
  end

  def icon_class
    connected ? 'text-car-battery' : 'opacity-40'
  end
end
