class ChargingSession::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see Ui::LazyRows)
  FRAME_PREFIX = 'sessions_page_'.freeze
  public_constant :FRAME_PREFIX

  # `previous_started_at`: see Ui::RowGroups
  def initialize(sessions:, pagy:, timeframe:, previous_started_at: nil, frame: false)
    super()
    @pagy = pagy
    @timeframe = timeframe
    @groups = Ui::RowGroups.new(sessions, timeframe:, previous_started_at:)
    @frame = frame
  end

  attr_reader :groups, :pagy, :frame

  # The known place at the position of a session without an address. The
  # places come from one query, and Nominatim gets no request.
  def place_of(charging_session)
    return if charging_session.address.present? || charging_session.latitude.nil?

    Place.near(charging_session.latitude, charging_session.longitude, places)
  end

  # The list of the group alone, with the kind and the car filter of the list
  # A list of a day has its only group already, so its header has no link
  def group_path(group) = (timeframe_page.path(group.to_param) unless @timeframe.day?)

  private

  def places
    @places ||= Place.all.to_a
  end

  def timeframe_page = @timeframe_page ||= helpers.timeframe_page
end
