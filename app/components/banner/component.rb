class Banner::Component < ViewComponent::Base
  def initialize(registration_status:, prompt:, admin:)
    super
    @registration_status = registration_status.to_s.inquiry
    @prompt = prompt
    @admin = admin
  end

  attr_reader :registration_status, :admin

  delegate :pending?, :unregistered?, to: :registration_status

  def prompt?
    @prompt
  end
end
