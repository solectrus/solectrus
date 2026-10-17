# The battery of the car as a gauge: an arc of 240 degrees from 0 to the
# maximum range, filled to the state of charge. The remaining range sits in
# the center. The block of the component stands right above the arc, the
# footer right below it, so both stay close to the arc.
class Car::RangeGauge::Component < ViewComponent::Base
  include Car::BatteryDisplay

  # The arc around (200, 175) with a radius of 150, open at the bottom
  ARC = 'M 70 250 A 150 150 0 1 1 330 250'.freeze
  public_constant :ARC

  # A badge below the plug and the charging power, for example the place
  renders_one :location

  # The block below the arc, for example the odometer
  renders_one :footer

  # A center of its own in place of the range, the state of charge and the
  # plug, for example the note that no car is in use
  renders_one :center

  # `state` holds the values of one car (see Car::Live::State)
  def initialize(state:)
    super()
    @state = state
  end

  attr_reader :state

  # The height that the arc leaves free: 1rem of room, and the height of the
  # block above (4rem, two lines like the name and the time) and of the
  # footer below (2.75rem), each with its gap of 1.5rem. A CSS variable keeps
  # the class of the width static for Tailwind.
  def reserve_style
    rem = (content? ? 5.5 : 0) + (footer? ? 4.25 : 0) + 1
    "--gauge-reserve: #{rem}rem"
  end

  # The arc is always blue (see --color-car-battery)
  ARC_CLASS = 'stroke-car-battery'.freeze
  public_constant :ARC_CLASS
end
