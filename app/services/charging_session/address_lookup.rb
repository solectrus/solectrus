# Asks Nominatim for the position of the address of an offsite session (see
# ChargingSession::Location). A request takes seconds, so the caller runs the
# lookup before the save, and no transaction of the database waits for it.
#
# It gives an address that waits for its position (see
# ChargingSession::Location#position_pending?) its position and its normal
# form: "DE-12345 Town, Main Street 15". Else it notes the problem in the
# session, and the validation of the session reports it. The form carries the
# position for the address it found, so a save after the check of the form
# asks Nominatim no second time.
class ChargingSession::AddressLookup
  def initialize(session)
    @session = session
  end

  # Looks up the address, and saves the session after the lookup. The save
  # opens the transaction.
  def save
    look_up
    session.save
  end

  # The form checks the address without a save, so the session shows the
  # problem at once
  def check
    look_up
    session.validate_address
  end

  # Prepares the form when the user opens the session, without a request to
  # Nominatim, so the page does not wait for it. The form carries the
  # position for the address. If the form needs Nominatim (see #pending?),
  # it asks once it opened (see #complete).
  def prepare
    session.address_of_position = session.address if session.location
  end

  # Whether the form asks Nominatim once it opened: for an address from
  # before without its position, or for a position without an address
  def pending?
    Place::Nominatim.enabled? && session.address.present? != session.location.present?
  end

  # Completes the form once it opened (see #prepare). An address from before
  # gets its position and its normal form, and the save keeps them. A
  # position without an address offers the address at it (see
  # Place.address_at). The form then carries the position for the address.
  def complete
    check if session.position_pending?
    return unless session.location

    session.address = Place.address_at(*session.location) if session.address.blank?
    session.address_of_position = session.address
  end

  private

  attr_reader :session

  def look_up
    session.address_problem = nil
    restore_position
    # Without Nominatim, the session keeps the position of its car (see
    # ChargingSession::Location)
    return unless session.position_pending? && Place::Nominatim.enabled?

    session.assign_attributes(latitude: nil, longitude: nil, address_of_position: nil)
    return unless session.address

    place = Place.search(session.address)
    return session.address_problem = :not_found unless place

    address = Place::PostalAddress.parse(session.address).completed_by(place.postal_parts).to_s
    session.assign_attributes(address:, latitude: place.latitude, longitude: place.longitude, address_of_position: address)
  rescue Place::Nominatim::Unavailable
    session.address_problem = :unavailable
  end

  # The saved address has its saved position. The form can carry the
  # position of another address that the user checked before, so this
  # position goes. The form then carries the saved position, so the user
  # can move its point.
  def restore_position
    return if session.will_save_change_to_address? || session.position_carried?

    session.restore_attributes(%i[latitude longitude])
    session.address_of_position = session.address if session.location
  end
end
