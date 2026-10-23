# One page of the places of the list (see Place::VisitedList::Component)
class Place::VisitedList::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see Ui::LazyRows)
  FRAME_PREFIX = 'places_page_'.freeze
  public_constant :FRAME_PREFIX

  def initialize(rows:, pagy:, visits_path:, frame: false)
    super()
    @rows = rows
    @pagy = pagy
    @visits_path = visits_path
    @frame = frame
  end

  attr_reader :rows, :pagy, :visits_path, :frame

  def places = @places ||= Place.where(id: rows.map(&:place_id)).index_by(&:id)

  def cars = @cars ||= Car.configured.index_by(&:id)
end
