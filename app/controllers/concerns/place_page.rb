# A page of the places below the car page: the list of the visits and the map
# of the places. Each has a timeframe and a select of the cars with a
# location, and builds the days that wait for the visits first (see
# PlaceVisitsBuild). The controller names its route (#page_route), and adds
# its parameters (#page_params).
module PlacePage
  extend ActiveSupport::Concern
  include PlaceVisitsBuild
  include CarListPage

  included do
    private

    # Like CarSelectable, but without its selection_params, which would
    # change the timeframe navigation and the frame ids of a list
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

    helper_method def car_select_component(**)
      Car::Select::Component.new(cars: located_cars, car:, path: ->(id) { page_path_with(car: id) }, **)
    end

    # The page with the changes, for a link to another page
    helper_method def page_path_with(**changes) = path_for(page_route, **page_params, **changes)

    # The pages of the places in the header, each in the timeframe and with
    # the car of the page. The map comes first, because the driving card
    # opens it. The current page keeps its own parameters, like the place of
    # the list of the visits.
    helper_method def nav_items
      { cars_place_map_path: t('car_breakdown.places'), cars_visits_path: t('visits.name') }.map do |route, name|
        current = route == page_route
        { name:, href: current ? page_path_with : path_for(route, car: car_selection.to_param), current: }
      end
    end

    # The distance on the car page, whose card links to the page, in the
    # timeframe and with the car of the page
    helper_method def back_path
      cars_home_path(sensor_name: 'car_distance', timeframe: timeframe.to_param, car: car_selection.to_param)
    end

    # The visits are whole days (see PlaceVisit.overlapping)
    helper_method def timeframe_page
      TimeframePage::List.new(route: page_route, params: page_params, hours: false)
    end
  end

  private

  # The car of the page, which each link of the page keeps. The car stays
  # also as nil for "all", because Rails takes a missing car from the current
  # address.
  def page_params = { car: car_selection.to_param }

  # The whole time has no timeframe in the address
  def path_for(route, **) = public_send(route, timeframe: (timeframe.to_param unless timeframe.all?), **)

  # Only the days of the page wait for the build
  def build_timeframe = timeframe
end
