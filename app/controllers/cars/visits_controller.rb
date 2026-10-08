# The visits of the cars at the places, the latest first, each visit in one
# row (see PlaceVisit.joined). Like the list of the charging sessions, the
# page has a timeframe and a car select. A place in the address narrows the
# list to the visits of this place (/cars/places/2/visits), a link of the
# list of the places. It shows as a chip that removes it.
#
# The page builds the days that wait for the visits first (see
# PlaceVisitsBuild).
class Cars::VisitsController < ApplicationController
  include Pagy::Method
  include PlaceVisitsBuild
  include CarListPage

  # Each page of the list loads into a Turbo frame of its own (see LazyRows)
  PAGE_FRAME_PREFIX = 'visits_page_'.freeze
  public_constant :PAGE_FRAME_PREFIX

  def index
    # A car that the page does not offer goes to "all", like on the car page
    return redirect_to(visits_path_with(car: nil)) unless car_selection.valid?

    # While days wait for the build, the page shows the build instead of the list
    @pending_days = page_frame_request? ? [] : pending_visit_days
    return if @pending_days.present?

    @pagy, @visits = pagy(:countless, visits)

    # Only a list up to now can hold an ongoing visit
    PlaceVisit.mark_ongoing(@visits) unless timeframe.past?

    render partial: 'rows', locals: { visits: @visits, pagy: @pagy, frame: true } if page_frame_request?
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

  # Like CarSelectable, but without its selection_params, which would
  # change the timeframe navigation and the frame ids of the list
  helper_method def car_selection
    @car_selection ||= CarSelection.new(params[:car], timeframe:)
  end

  # The selected car, or nil for "all"
  helper_method def car = car_selection.car

  # The cars of the timeframe with a location. Only they have visits.
  helper_method def located_cars
    @located_cars ||= car_selection.offered.select(&:located?)
  end

  # With more than one car with a location, the select stays also for a
  # timeframe with one car, so it does not come and go with the timeframe
  helper_method def car_select?
    Car.configured.many?(&:located?)
  end

  # The car and the place of the list, which each link of the page keeps. The
  # car stays also as nil for "all", because Rails takes a missing car from
  # the current address.
  def list_params = { car: car_selection.to_param, place: place&.id }

  # The list with the changes, for a link to another list. The whole time
  # has no timeframe in the address.
  helper_method def visits_path_with(**changes)
    cars_visits_path(timeframe: (timeframe.to_param unless timeframe.all?), **list_params, **changes)
  end

  # The map of the places on the car page, in the timeframe and with the car
  # of the list
  helper_method def back_path
    cars_home_path(sensor_name: 'car_location', timeframe: timeframe.to_param, car: car_selection.to_param)
  end

  helper_method def timeframe_page
    # The list reads whole days (see PlaceVisit.overlapping)
    TimeframePage::List.new(route: :cars_visits_path, params: list_params, hours: false)
  end

  # Only the days of the list wait for the build
  def build_timeframe = timeframe

  # The list of the whole time starts with the latest visits, so the current
  # day keeps the tolerance of a day and not the one of the whole time
  def pending_visit_days
    days = super
    return days unless timeframe.all?

    (days | Summary.missing_or_stale_days_for(Timeframe.new('day'), steps: [Place::VisitDetection::KEY])).sort
  end

  def page_frame_request? = LazyRows::Component.request?(request, PAGE_FRAME_PREFIX)

  # The car of a visit needs a column only with more than one car, and not
  # in the list of one car
  helper_method def car_column?
    return @car_column if defined?(@car_column)

    @car_column = !car && located_cars.many?
  end

  helper_method def title
    t('visits.name')
  end
end
