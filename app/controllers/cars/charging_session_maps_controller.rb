# The offsite sessions on a map that fills the window over their list (see
# ChargingSession::Map::Component and Car::MapOverlay::Component). Only the
# admin sees it. The wallbox sessions have none, because they share one
# place. The map has no page of its own, so its address alone leads to the
# list.
class Cars::ChargingSessionMapsController < ApplicationController
  include CarListPage

  def index
    # A car that the page does not offer goes to "all", like on the car page
    return redirect_to(cars_charging_session_map_path(timeframe: timeframe.to_param, car: nil)) unless car_selection.valid?

    redirect_to(list_address) unless turbo_frame_request?
  end

  private

  helper_method def car_selection
    @car_selection ||= CarSelection.new(params[:car], timeframe:, guest: true)
  end

  # The list below the map, where a form that the map opens leads back to
  helper_method def list_address
    cars_charging_sessions_path(kind: 'offsite', timeframe: timeframe.to_param, car: car_selection.to_param)
  end

  # The map loads the spots of the sessions that count alone, and each
  # tooltip loads its sessions (see Cars::SpotTooltipsController)
  helper_method def map_component
    ChargingSession::Map::Component.new(
      scope: ChargingSession.listed('offsite', timeframe:, filter: car_selection.filter),
      tooltip_url: cars_spot_tooltip_path(car: car_selection.to_param, spot: ':id', timeframe: timeframe.to_param),
    )
  end
end
