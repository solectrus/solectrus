# The list of the places or of the visits of the cars (see
# Car::ListBox::Component): the switch between the places and the visits,
# their numbers, the button of the map of the places, and the list. The list
# of the visits can show the visits of one place. Its pill in the head
# names the place, and its x shows the visits of all places again.
#
# In the sheet of a phone, the head has no numbers, and the sheet has the
# button of the map in its head (see SheetPage).
class Place::ListBox::Component < ViewComponent::Base
  # `list` is "places" or "visits". `counts` are the numbers of the visits and
  # of their places (see PlaceVisit.counts). `segments` are the items of the
  # switch, and `component` is the list. `place` narrows the visits, and
  # `unfiltered_path` is the list without it. `sheet` is true in the sheet
  # of a phone.
  def initialize(list:, counts:, segments:, map_path:, component:, timeframe:, place: nil, unfiltered_path: nil, sheet: false) # rubocop:disable Metrics/ParameterLists
    super()
    @sheet = sheet
    @list = list
    @timeframe = timeframe
    @counts = counts
    @segments = segments
    @map_path = map_path
    @component = component
    @place = place
    @unfiltered_path = unfiltered_path
  end

  attr_reader :segments, :component, :place, :unfiltered_path, :sheet

  # An empty list says so instead, and has no numbers and nothing on the map
  def map_path = (@map_path if visits?)

  def map_label = t('.map')

  # The places have the number of the places. The visits have the number of
  # the visits and of their places, but the visits of one place need no
  # number of places. The sheet of a phone has no room for them, the rows
  # name the visits of each place.
  def totals
    return unless visits?
    return if sheet && !place

    return t('.places', count: @counts[:places]) if @list == 'places'

    visits = t('visits.count', count: @counts[:visits])
    return visits if place

    t('.visits_at', visits:, places: t('.at_places', count: @counts[:places]))
  end

  # The title of an empty list names the list. "Not yet" fits a timeframe
  # that still runs.
  def empty_title = t(".empty.#{@list}.#{@timeframe.current? ? 'current' : 'past'}")

  def visits? = @counts[:visits].positive?
end
