class ActionRequired::Component < ViewComponent::Base
  def initialize(registration_status:, admin:)
    super()
    @registration_status = registration_status.to_s.inquiry
    @admin = admin
  end

  attr_reader :registration_status, :admin

  delegate :unknown?, to: :registration_status, allow_nil: true

  def tooltip
    registration_status.complete? ? t('.prompt') : t(".#{registration_status}")
  end
end
