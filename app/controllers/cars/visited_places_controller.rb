# The places of the cars, each with its cars, the number of its visits and its
# latest visit, the most visited place first (see Place::VisitedList). A switch
# leads to the list of the visits, and a button to the map of the places. Like
# the list of the charging sessions, the page has a timeframe and a car select.
class Cars::VisitedPlacesController < ApplicationController
  include Cars::PlacePage
  include ListAddress

  def index
    return render_next_page if next_page?

    # A car that the page does not offer goes to "all", like on the car page
    return redirect_to(page_path_with(car: nil)) unless car_selection.valid?

    # While days wait for the build, the page shows the build instead of the list
    @pending_days = Sensor::Summarizer.build_few(pending_visit_days)
  end

  private

  def page_route = :cars_visited_places_path

  def next_page? = Ui::LazyRows::Component.request?(request, Place::VisitedList::Rows::Component::FRAME_PREFIX)

  def render_next_page
    pagy, rows = places_page
    render Place::VisitedList::Rows::Component.new(rows:, pagy:, visits_path: method(:place_visits_path), frame: true), layout: false
  end

  helper_method def list_box
    @list_box ||= begin
      pagy, rows = places_page
      place_list_component('places', Place::VisitedList::Component.new(rows:, pagy:, visits_path: method(:place_visits_path)))
    end
  end

  # The places with their visits, the most visited first, a page at a time
  def places_page = pagy(:countless, PlaceVisit.by_place(joined_visits))

  helper_method def title = t('car_breakdown.places')
end
