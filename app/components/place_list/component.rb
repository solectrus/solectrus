# The places where the cars stood, each with the time of the cars there: a
# table on the desktop, a grouped list on a phone (see
# PlaceList::Row::Component).
class PlaceList::Component < ViewComponent::Base
  def initialize(places:, pagy:)
    super()
    @places = places
    @pagy = pagy
  end

  attr_reader :places, :pagy
end
