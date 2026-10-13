class PlaceList::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see LazyRows)
  FRAME_PREFIX = 'places_page_'.freeze
  public_constant :FRAME_PREFIX

  def initialize(places:, pagy:, frame: false)
    super()
    @places = places
    @pagy = pagy
    @frame = frame
  end

  attr_reader :places, :pagy, :frame
end
