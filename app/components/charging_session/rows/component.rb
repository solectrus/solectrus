class ChargingSession::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own
  FRAME_PREFIX = 'sessions_page_'.freeze
  public_constant :FRAME_PREFIX

  def self.frame_id(page) = "#{FRAME_PREFIX}#{page}"

  def initialize(sessions:, pagy:)
    super()
    @sessions = sessions
    @pagy = pagy
  end

  attr_reader :sessions, :pagy

  def next_page_frame_id
    self.class.frame_id(pagy.next)
  end

  def next_page_src
    pagy.page_url(:next)
  end
end
