class VisitList::NameCell::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  attr_reader :place

  # The name of the place, or the part of the town where it is, which is
  # shorter than the locality. The desktop has the town beside it (see
  # LocalityCell).
  def name
    place.name || place.district || place.town || t('settings.places.unnamed')
  end

  def name_class
    return if place.name

    place.town ? 'text-muted' : 'italic text-muted'
  end
end
