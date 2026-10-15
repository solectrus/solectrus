# One place: a row of the table on the desktop, a cell of a grouped list on
# a phone (see Ui::TableRow::Component). Each opens the form of the
# place.
class Place::List::Row::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  attr_reader :place

  def edit_path
    helpers.edit_settings_place_path(place)
  end

  def name
    place.name || t('settings.places.unnamed')
  end

  def duration
    DurationText.call(place.seconds) if place.seconds.positive?
  end
end
