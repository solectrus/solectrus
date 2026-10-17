# The visits of the cars at the places, the latest first, each visit in one
# row (see PlaceVisit.joined). Like the list of the charging sessions, the
# page has a timeframe and a car select. A place in the address narrows the
# list to the visits of this place (/cars/places/2/visits), a link of the
# list of the places. It shows as a chip that removes it.
class Cars::VisitsController < ApplicationController
  include Pagy::Method
  include PlacePage
  include ListAddress

  def index
    # A car that the page does not offer goes to "all", like on the car page
    return redirect_to(page_path_with(car: nil)) unless car_selection.valid?

    # While days wait for the build, the page shows the build instead of the list
    @pending_days = page_frame_request? ? [] : Sensor::Summarizer.build_few(pending_visit_days)
    return if @pending_days.present?

    @pagy, @visits = pagy(:countless, visits)

    # Only a list up to now can hold an ongoing visit
    PlaceVisit.mark_ongoing(@visits) unless timeframe.past?

    return unless page_frame_request?

    previous_started_at = visits.offset(@pagy.offset - 1).pick(:started_at)
    render Place::VisitList::Rows::Component.new(visits: @visits, pagy: @pagy, context: list_context, previous_started_at:, frame: true), layout: false
  end

  private

  def visits
    rows = PlaceVisit.all
    rows = rows.where(place:) if place
    rows = rows.where(car:) if car
    visits = rows.joined
    visits = visits.overlapping(timeframe) unless timeframe.all?
    visits.preload(:place, :car)
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

  def page_frame_request? = Ui::LazyRows::Component.request?(request, Place::VisitList::Rows::Component::FRAME_PREFIX)

  # What each row of the list needs to know about the list. The car of a
  # visit needs a column only with more than one car, and not in the list of
  # one car.
  helper_method def list_context
    @list_context ||= Place::VisitList::Context.new(timeframe:, place:, car_column: !car && located_cars.many?, path: method(:page_path_with))
  end

  helper_method def title
    t('visits.name')
  end
end
