# Checks the address of the form of an offsite session (see the
# address-lookup controller) and answers with the address in its normal form
# and its map, or with an error. It saves nothing. A saved session compares
# the address with the saved one. With `opened`, the form asks for what the
# edit left to it (see ChargingSession::AddressLookup#complete).
class Cars::ChargingSessionAddressesController < ApplicationController
  include CarPageGate

  def create
    @charging_session = params[:id] ? ChargingSession.offsite.find(params.expect(:id)) : ChargingSession.new(kind: :offsite)
    @charging_session.assign_attributes(params.expect(charging_session: %i[address address_of_position latitude longitude]))
    lookup = ChargingSession::AddressLookup.new(@charging_session)
    params[:opened] ? lookup.complete : lookup.check
  end
end
