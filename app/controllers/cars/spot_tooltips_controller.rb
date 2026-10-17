# The tooltip of a spot on the map of the offsite sessions (see
# ChargingSession::SpotTooltip::Component). The map loads it when the pointer
# rests on a spot, so the page carries only the positions of the spots. The
# tooltip takes the sessions of the timeframe and of the car filter of the
# list.
class Cars::SpotTooltipsController < ApplicationController
  include CarPageGate

  def show
    timeframe = Timeframe.new(params.expect(:timeframe))
    selection = CarSelection.new(params[:car], timeframe:, extras: true)
    scope = ChargingSession.listed('offsite', timeframe:, filter: selection.filter)
    spot = ChargingSession::Spot.find(scope, params.expect(:spot))
    return head(:not_found) unless spot

    render ChargingSession::SpotTooltip::Component.new(spot:), layout: false
  end
end
