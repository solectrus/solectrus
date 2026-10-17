# The battery of the car as a horizontal bar, for the live view with more
# than one car: the bar needs less height than the arc, so the cars fit on a
# phone one below the other (see Car::LiveView::Component). It shows the
# same values as the gauge (see Car::RangeGauge::Component): the range and
# the state of charge above the bar, the scale from 0 to the maximum range
# below it, and between the ends of the scale the plug and the charging
# power.
class Car::RangeBar::Component < ViewComponent::Base
  include Car::BatteryDisplay

  # `state` holds the values of one car (see Car::Live::State)
  def initialize(state:)
    super()
    @state = state
  end

  attr_reader :state
end
