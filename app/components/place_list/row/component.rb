# One place, a row of the table that opens the form of the place. A stream
# replaces it after a change.
class PlaceList::Row::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  attr_reader :place

  def edit_path
    helpers.edit_settings_place_path(place)
  end

  def name
    place.display_name || t('settings.places.unnamed')
  end

  def duration
    DurationText.call(place.seconds) if place.seconds.positive?
  end

  # The locality, when the name stands in its place, and the position
  def details
    [(place.locality if place.name), "#{place.latitude.round(5)}, #{place.longitude.round(5)}"].compact.join(' · ')
  end
end
