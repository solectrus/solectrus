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

  before_action :admin_required!
  before_action(except: :index) { head(:not_found) unless sponsored? }
  before_action :load_place, only: %i[edit update]

  # Each page of the list loads into a Turbo frame of its own (see LazyRows)
  PAGE_FRAME_PREFIX = 'places_page_'.freeze
  public_constant :PAGE_FRAME_PREFIX

  def index
    return unless sponsored?

    next_page = LazyRows::Component.request?(request, PAGE_FRAME_PREFIX)

    # While days wait for the build, the page shows the build instead of the list
    @pending_days = next_page ? [] : pending_visit_days
    return if @pending_days.present?

    @pagy, @places = pagy(:countless, Place.with_seconds)
    render partial: 'rows', locals: { places: @places, pagy: @pagy, frame: true } if next_page
  end

  def edit
    @place.geocode!
  end

  # A new home takes the label from the old home (see Place), so the row of
  # the old home changes too, and the notice names it
  def update
    previous_home = Place.home
    if @place.update(permitted_params)
      moved = previous_home if previous_home != @place && @place.home?
      flash.now[:notice] = moved ? t('settings.places.home_moved', previous: moved.display_name || t('settings.places.unnamed')) : t('crud.success')
      render turbo_stream: [*[@place, moved].compact.flat_map { replace_place(it) }, turbo_stream_update_flash]
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  helper_method def sponsored? = Sensor::HomePage.permitted?(:cars)

  # The form opens from the list of the places and from the list of the
  # visits. Each list replaces what it shows of the place.
  helper_method def replace_place(place)
    [
      turbo_stream.replace(helpers.dom_id(place), partial: 'settings/places/row', locals: { place: Place.with_seconds.find(place.id) }),
      turbo_stream.replace_all("[data-visit-place-name='#{place.id}']", partial: 'cars/visits/place_name', locals: { place: }),
      turbo_stream.replace_all("[data-visit-place-locality='#{place.id}']", partial: 'cars/visits/place_locality', locals: { place: }),
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
    params.expect(place: [:name, { labels: [] }])
  end

  def load_place
    @place = Place.find(params.expect(:id))
  end
end
