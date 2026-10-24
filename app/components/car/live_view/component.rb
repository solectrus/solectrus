# The live view of the car page: a card for each car in use today (see
# Car::LiveCard::Component). The live view has no select, so each card names
# its car. A phone shows the cards one below the other, from the top, on the
# gray of the page. A wider screen shows them side by side. One car stands in
# the middle, at most 35rem wide, and on the desktop 64rem.
#
# The wallbox gets a card of its own while it charges and no car shows its
# power: a guest charges, or no car has a plug. With the plugs of the cars,
# the card names the guest, and else the wallbox.
#
# Without a car in use today, a card with a note takes the place of the cars.
class Car::LiveView::Component < ViewComponent::Base
  include Car::TimeText

  # `live` is a Car::Live
  def initialize(live:)
    super()
    @live = live
  end

  attr_reader :live

  delegate :wallbox_power, to: :live

  def states
    @states ||= live.states
  end

  # The wallbox charges, and no car shows its power
  def wallbox? = wallbox_power.to_f.positive? && !live.car_at_wallbox?

  # A plug of a car tells that none of them charges, so a guest does
  def guest? = states.any? { !it.connected.nil? }

  def wallbox_time = time_text(live.data.time_for(:wallbox_power))

  def cards = states.size + (wallbox? ? 1 : 0)

  # The class names stay literal, so Tailwind finds them
  def card_classes
    cards == 1 ? 'sm:w-full sm:max-w-[35rem] lg:max-w-5xl' : 'sm:flex-1 sm:max-w-[37.5rem]'
  end
end
