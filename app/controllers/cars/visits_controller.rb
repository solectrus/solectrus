# The visits of the cars at the places, the latest first, each visit in one
# row (see PlaceVisit.joined). The list has a switch to the list of the places
# and a button to their map (see Cars::PlaceListing). A place in the address
# (/cars/places/2/visits) narrows the list to the visits of this place, with
# a pill in the head that removes it again. The number of the visits in the
# list of the places links it.
class Cars::VisitsController < ApplicationController
  include Cars::PlacePage
  include ListAddress

  def index
    # A car that the page does not offer goes to "all", like on the car page
    return redirect_to(page_path_with(car: nil)) unless car_selection.valid?

    # While days wait for the build, the page shows the build instead of the list
    @pending_days = next_page? ? [] : Sensor::Summarizer.build_few(pending_visit_days)
    return if @pending_days.present?

    load_visits
    render_next_page if next_page?
  end

  private

  def load_visits
    @pagy, @visits = pagy(:countless, joined_visits(place:).preload(:place, :car))

    # Only a list up to now can hold an ongoing visit
    PlaceVisit.mark_ongoing(@visits) unless timeframe.past?
  end

  def render_next_page
    previous_started_at = joined_visits(place:).offset(@pagy.offset - 1).pick(:started_at)
    render Place::VisitList::Rows::Component.new(visits: @visits, pagy: @pagy, context: list_context, previous_started_at:, frame: true), layout: false
  end

  helper_method def place
    return @place if defined?(@place)

    @place = (Place.find(params.expect(:place)) if params.key?(:place))
  end

  def page_route = :cars_visits_path

  # Each link of the page keeps the place too
  def page_params = { **super, place: place&.id }

  # The list of the whole time starts with the latest visits, so the current
  # day keeps the tolerance of a day and not the one of the whole time
  def pending_visit_days
    days = super
    return days unless timeframe.all?

    (days | Summary.missing_or_stale_days_for(Timeframe.new('day'))).sort
  end

  def next_page? = Ui::LazyRows::Component.request?(request, Place::VisitList::Rows::Component::FRAME_PREFIX)

  # What each row of the visits needs to know about the list. The car of a
  # visit needs a column only with more than one car, and not in the list of
  # one car. A group opens the list in its timeframe, with the place.
  def list_context
    @list_context ||= Place::VisitList::Context.new(
      timeframe:,
      car_column: !car_selection.car && car_selection.offered.many?(&:located?),
      path: ->(timeframe:) { cars_visits_path(car: car_selection.car&.id, place: place&.id, timeframe: (timeframe unless timeframe == 'all')) },
    )
  end

  # The list with the switch to the places, narrowed to the place of the
  # address
  helper_method def list_box
    @list_box ||= place_list_component('visits', Place::VisitList::Component.new(visits: @visits, pagy: @pagy, context: list_context), place:)
  end

  helper_method def title = t('car_breakdown.places')

  # In the sheet of a phone, the visits of a place lead back to the places
  # (see SheetPage)
  helper_method def sheet_back_path = (place_list_path('places') if place)
end
