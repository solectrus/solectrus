class Place::VisitList::NameCell::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  attr_reader :place

  # The name of the place, or where it is
  def name
    place.display_name || t('settings.places.unnamed')
  end

  # A place without a name is in italics
  def name_class
    'italic text-muted' unless place.name
  end
end
