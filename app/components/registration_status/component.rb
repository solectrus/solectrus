class RegistrationStatus::Component < ViewComponent::Base
  def initialize(registration_status:, admin:)
    super
    @registration_status = registration_status.presence
    @admin = admin
  end

  attr_reader :registration_status, :admin

  delegate :pending?,
           :unregistered?,
           :unknown?,
           :complete?,
           :skipped?,
           to: :registration_status,
           allow_nil: true
end
