class Place::VisitList::LocalityCell::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  attr_reader :place

  # The name of a place without a name is its district (see NameCell), so the
  # town follows. A district that names the town stands alone (see
  # Place#locality).
  def text
    return place.locality if place.name

    district = place.district
    place.town if district && place.town && district.exclude?(place.town)
  end
end
