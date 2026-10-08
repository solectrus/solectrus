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
end
