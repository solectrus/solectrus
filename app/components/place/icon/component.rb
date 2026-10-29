# The icon of a place at the start of its row: home as a house on indigo, a
# place with a name as a pin, and a place without a name as a pale pin. No
# place, like for a car on the road, has a pale pin too. The pill of a car
# in the live view has a small `round` icon (see Car::LiveCard::Component).
class Place::Icon::Component < ViewComponent::Base
  def initialize(place:, round: false)
    super()
    @place = place
    @round = round
  end

  def call
    tag.span(helpers.icon(@place&.home? ? 'house' : 'location-dot'), class: classes, aria: { hidden: true })
  end

  private

  def classes
    class_names(
      'flex shrink-0 items-center justify-center text-white',
      @round ? 'size-7 rounded-full text-xs' : 'size-8 rounded-lg text-sm',
      if @place&.home? then 'bg-indigo-600 dark:bg-indigo-500'
      elsif @place&.name then 'bg-slate-500'
      else 'bg-slate-400 dark:bg-slate-600'
      end,
    )
  end
end
