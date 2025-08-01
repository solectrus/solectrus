class SetupStatus::Component < ViewComponent::Base
  def initialize(registration_status:, prompt:, admin:)
    super()
    @registration_status = registration_status.to_s.inquiry
    @prompt = prompt
    @admin = admin
  end

  attr_reader :registration_status, :prompt, :admin

  delegate :unknown?, to: :registration_status, allow_nil: true

  def prompt?
    @prompt
  end

  def tooltip
    registration_status.complete? ? t('.prompt') : t(".#{registration_status}")
  end
end
