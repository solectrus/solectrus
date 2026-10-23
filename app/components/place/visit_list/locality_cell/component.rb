# The locality of a place with a name, after the name and a comma in a lighter
# gray. A place without a name has its locality as its name (see NameCell), so
# it stays empty. The form replaces each locality on the page after a change
# (see Settings::PlacesController).
class Place::VisitList::LocalityCell::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  def call
    tag.span((", #{@place.locality}" if @place.name && @place.locality), class: 'text-gray-500 dark:text-slate-400', data: { visit_place_locality: @place.id })
  end
end
