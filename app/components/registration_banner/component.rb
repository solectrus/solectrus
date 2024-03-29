class RegistrationBanner::Component < ViewComponent::Base
  def initialize(registration_status:, admin:)
    super
    @registration_status = registration_status
    @admin = admin
  end

  attr_reader :registration_status, :admin

  delegate :pending?, :unregistered?, to: :registration_status
end
