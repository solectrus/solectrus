class ChargingSession::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see LazyRows)
  FRAME_PREFIX = 'sessions_page_'.freeze
  public_constant :FRAME_PREFIX

  def initialize(sessions:, pagy:, frame: false)
    super()
    @sessions = sessions
    @pagy = pagy
    @frame = frame
  end

  attr_reader :sessions, :pagy, :frame

  # The known place at the position of a session without an address. The
  # places come from one query, and Nominatim gets no request.
  def place_of(charging_session)
    return if charging_session.address.present? || charging_session.latitude.nil?

    Place.near(charging_session.latitude, charging_session.longitude, places)
  end

  private

  def places
    @places ||= Place.all.to_a
  end
end
