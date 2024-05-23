class SetupStatus::Component < ViewComponent::Base
  def initialize(registration_status:, subscription_plan:, prompt:, admin:)
    super
    @registration_status = registration_status.to_s.inquiry
    @subscription_plan = subscription_plan.to_s.inquiry
    @prompt = prompt
    @admin = admin
  end

  attr_reader :registration_status, :subscription_plan, :admin

  delegate :pending?,
           :unregistered?,
           :unknown?,
           :complete?,
           to: :registration_status,
           allow_nil: true

  def sponsoring?
    subscription_plan.present?
  end

  def prompt?
    @prompt
  end

  def tooltip
    prompt? ? t('.prompt') : t(".#{registration_status}")
  end
end
