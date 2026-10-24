# The lists of the places and of the visits of the cars, pages below the car
# page with a switch between them. Each list loads its next pages from its
# own address. The controller gives `car_selection` and `timeframe`.
module Cars::PlaceListing
  extend ActiveSupport::Concern
  include Pagy::Method

  private

  # The box of the places or the visits with the switch between them, and
  # `component` as the list. A place narrows the visits, and the pill of the
  # place leads to the list without it. The sheet of a phone has the map in
  # its head (see SheetPage).
  def place_list_component(list, component, place: nil)
    Place::ListBox::Component.new(
      list:,
      counts: place_counts(place:),
      segments: place_list_items(list),
      sheet: sheet_page?,
      map_path: cars_place_map_path(**place_page_params),
      component:,
      timeframe:,
      place:,
      unfiltered_path: (place_list_path(list) if place),
    )
  end

  # The visits of the selected car, each in one row (see PlaceVisit.joined),
  # that overlap the timeframe. A place narrows them to its visits.
  def joined_visits(place: nil)
    rows = PlaceVisit.all
    rows = rows.where(place:) if place
    rows = rows.where(car: car_selection.car) if car_selection.car
    visits = rows.joined
    timeframe.all? ? visits : visits.overlapping(timeframe)
  end

  def place_counts(place: nil)
    rows = car_selection.car ? PlaceVisit.where(car: car_selection.car) : PlaceVisit.all
    rows = rows.where(place:) if place
    rows.counts(timeframe)
  end

  # The places and the visits, which switch the list. Their names do not
  # repeat the name of the page ("Places").
  def place_list_items(current)
    %w[places visits].map do |list|
      { name: t("car_breakdown.place_lists.#{list}"), href: place_list_path(list), current: list == current }
    end
  end

  # The list of the places or of the visits, in the timeframe and with the
  # car of this page
  def place_list_path(list, timeframe: self.timeframe.to_param)
    route = list == 'visits' ? :cars_visits_path : :cars_visited_places_path
    public_send(route, timeframe: (timeframe unless timeframe == 'all'), car: car_selection.car&.id, place: nil)
  end

  def place_visits_path(place_id) = cars_visits_path(**place_page_params, place: place_id)

  # The whole time has no timeframe in the address of the pages of the places
  def place_page_params = { timeframe: (timeframe.to_param unless timeframe.all?), car: car_selection.car&.id }
end
