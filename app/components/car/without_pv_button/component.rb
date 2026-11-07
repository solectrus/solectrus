# The button that adds the column without PV to a comparison or takes it
# away (see without_pv_toggle_controller.ts): the car without PV, or the heat
# pump without PV. Its labels follow the attribute of the page, without
# JavaScript. Both labels share one cell, so the button keeps its width, and
# a button beside it stays in place.
class Car::WithoutPvButton::Component < ViewComponent::Base
  # `pressed` is the choice that the server renders from the cookie
  def initialize(pressed:)
    super()
    @pressed = pressed
  end

  attr_reader :pressed
end
