# The places where the cars stood, each with the time of the cars there. The
# user gives a place a name of its own. The list asks Nominatim for no
# address. Only the edit form does (see Place#geocode!).
#
# The places come from the car page, so a sponsorship opens them like the car
# page (see Sensor::HomePage.permitted?). Without one, the list shows the
# upsell, and the form answers nothing.
class Settings::PlacesController < ApplicationController
  include SettingsNavigation
  include Pagy::Method
  include PlaceVisitsBuild
  include FormPageResponse

  before_action :admin_required!
  before_action(except: :index) { head(:not_found) unless sponsored? }
  before_action :load_place, only: %i[edit update destroy]

  def index
    return unless sponsored?

    next_page = LazyRows::Component.request?(request, PlaceList::Rows::Component::FRAME_PREFIX)

    # While days wait for the build, the page shows the build instead of the list
    @pending_days = next_page ? [] : pending_visit_days
    return if @pending_days.present?

    @pagy, @places = pagy(:countless, Place.with_seconds)
    render PlaceList::Rows::Component.new(places: @places, pagy: @pagy, frame: true), layout: false if next_page
  end

  def edit
    @place.geocode!
  end

  # A new home takes the label from the old home (see Place), so the row of
  # the old home changes too, and the notice names it
  def update
    previous_home = Place.home
    if @place.update(permitted_params)
      @moved = previous_home if previous_home != @place && @place.home?
      notice = @moved ? t('settings.places.home_moved', previous: @moved.display_name || t('settings.places.unnamed')) : t('crud.success')
      respond_with_list(notice:)
    else
      respond_with_errors(@place)
    end
  end

  # Only a place without a visit can go (see Place#deletable?)
  def destroy
    return head(:unprocessable_content) unless @place.deletable?

    @place.destroy!
    respond_with_list(notice: t('crud.deleted'))
  end

  private

  # A place without a visit shows in the list of the places alone
  def list_stream
    return turbo_stream.remove(helpers.dom_id(@place)) if @place.destroyed?

    [@place, @moved].compact.flat_map { replace_place(it) }
  end

  # The form opens from the list of the places and from the list of the
  # visits, which passes itself as return_to (see FormPageResponse)
  def default_list_path
    settings_places_path
  end

  helper_method def list_title
    return_to ? t('visits.name') : title
  end

  # The visits at the place, with the car and the timeframe of the list of
  # the visits that opened the form. None when that list shows only this
  # place already.
  helper_method def place_visits_path
    list = visits_list_params
    cars_visits_path(**list, place: @place.id) unless list[:place] == @place.id.to_s
  end

  # The number of the visits that place_visits_path lists
  helper_method def place_visits_count
    @place_visits_count ||= begin
      list = visits_list_params
      visits = PlaceVisit.where(place: @place)
      visits = visits.where(car_id: list[:car]) if list[:car]
      visits.counts(visits_list_timeframe)[:visits]
    end
  end

  # The timeframe of the list of the visits. Like the list, an invalid one
  # falls back to the whole time (see CarListPage#timeframe).
  def visits_list_timeframe
    Timeframe.new(visits_list_params[:timeframe] || 'all')
  rescue ArgumentError
    Timeframe.new('all')
  end

  # The place that is home, or nil
  helper_method def current_home
    return @current_home if defined?(@current_home)

    @current_home = Place.home
  end

  # The form has the switch for home while no place or this place is home.
  # Home moves from another place only with an action of its own, which asks
  # first, because the move builds each day again (see the edit view).
  helper_method def home_switch? = current_home.nil? || current_home == @place

  helper_method def sponsored? = Sensor::HomePage.permitted?(:cars)

  # The form opens from the list of the places and from the list of the
  # visits. Each list replaces what it shows of the place.
  helper_method def replace_place(place)
    [
      turbo_stream.replace(helpers.dom_id(place), PlaceList::Row::Component.new(place: Place.with_seconds.find(place.id))),
      turbo_stream.replace_all("[data-visit-place-labels='#{place.id}']", VisitList::LabelsCell::Component.new(place:)),
      turbo_stream.replace_all("[data-visit-place-name='#{place.id}']", VisitList::NameCell::Component.new(place:)),
      turbo_stream.replace_all("[data-visit-place-locality='#{place.id}']", VisitList::LocalityCell::Component.new(place:)),
    ]
  end

  # The data of Car::Map::Component: the place as its one marker
  helper_method def map_cars
    [{ places: [[@place.latitude, @place.longitude, 1]] }]
  end

  helper_method def title
    t('settings.places.name')
  end

  def permitted_params
    params.expect(place: %i[name home])
  end

  def load_place
    @place = Place.find(params.expect(:id))
  end

  # The car, the timeframe and the place of the list of the visits that
  # opened the form
  def visits_list_params
    @visits_list_params ||= return_to_params('cars/visits').slice(:car, :timeframe, :place)
  end
end
