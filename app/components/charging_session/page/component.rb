class ChargingSession::Page::Component < ViewComponent::Base
  def initialize(sessions:, pagy:)
    super()
    @sessions = sessions
    @pagy = pagy
  end

  attr_reader :sessions, :pagy

  def frame_id
    ChargingSession::Rows::Component.frame_id(pagy.page)
  end
end
