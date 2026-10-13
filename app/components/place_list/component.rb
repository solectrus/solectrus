# The places where the cars stood, each with the time of the cars there, as a
# table whose pages load one after the other (see LazyRows)
class PlaceList::Component < ViewComponent::Base
  def initialize(places:, pagy:)
    super()
    @places = places
    @pagy = pagy
  end

  attr_reader :places, :pagy
end
