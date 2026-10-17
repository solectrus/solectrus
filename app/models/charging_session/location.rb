# The position of an offsite session, where the car charged. It always fits
# the address:
#
# - A session with an address has the position of its address, from
#   Nominatim (see ChargingSession::AddressLookup). A new address without its
#   position is an error, so a caller that saves a new address runs the
#   lookup first. The build does not change the position (see
#   ChargingSession::OffsiteDetection::EnteredState).
# - A session without an address has the position of its car during its
#   rise, which the build writes, or none. An address without a position
#   gets this position too.
#
# Without Nominatim (an empty NOMINATIM_URL), an address stays as the user
# wrote it, and the session gets the position of its car. The build then
# writes it like the position of a session without an address.
module ChargingSession::Location
  extend ActiveSupport::Concern

  included do
    # The address that the form carries the position for: the address at the
    # position of the car (see Place.address_at), or the address that the
    # lookup found. A save with this address keeps the position.
    attribute :address_of_position, :string

    # Why the lookup gave the address no position: :not_found or :unavailable
    attr_accessor :address_problem

    validate :validate_address

    # The form carries the position (see #position_carried?)
    validates :latitude, numericality: { in: -90..90 }, allow_nil: true
    validates :longitude, numericality: { in: -180..180 }, allow_nil: true

    # The position of a rise belongs to the car and its day (see
    # #forget_rise). Only an offsite session has a position.
    before_save :forget_rise, if: -> { offsite? && persisted? && (will_save_change_to_car_id? || other_day?) }
  end

  def location = ([latitude, longitude] if latitude && longitude)

  # Whether the position belongs to the address and not to the rise. Without
  # Nominatim, an address has no position of its own.
  def position_of_address? = Place::Nominatim.enabled? && address.present?

  # Whether the form carries the position for the address
  def position_carried? = address.present? && !location.nil? && address == address_of_position

  # Whether the address still waits for its position: a new address, or an
  # address without a position, unless the form carries the position for
  # it. A removed address waits too, so the lookup removes the position.
  def position_pending?
    offsite? && !position_carried? && (will_save_change_to_address? || unlocated?)
  end

  # A new address needs its position. An address from before that Nominatim
  # does not find is an error too. Without an answer of Nominatim, only a new
  # address is an error, so the user can still change the rest of a session
  # from before.
  def validate_address
    return unless address.present? && position_pending?

    if will_save_change_to_address?
      errors.add(:address, address_problem || :not_found) if Place::Nominatim.enabled?
    elsif address_problem == :not_found
      errors.add(:address, :not_found)
    end
  end

  private

  def unlocated? = address.present? && location.nil?

  # Another car or another day has another rise, so the position of the old
  # rise goes. An address with a position from Nominatim keeps it. The address
  # that the form offered at the old position (see Place.address_at) goes too:
  # a new address at the saved position. Without Nominatim, each position
  # belongs to the rise.
  def forget_rise
    if position_of_address?
      return unless offered_address?

      self.address = nil
    end
    self.latitude = self.longitude = nil
  end

  def offered_address?
    address_in_database.blank? && !location.nil? && !will_save_change_to_latitude? && !will_save_change_to_longitude?
  end

  def other_day? = started_at_in_database&.to_date != started_at&.to_date
end
