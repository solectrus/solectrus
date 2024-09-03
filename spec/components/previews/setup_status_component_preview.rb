# @label SetupStatus
class SetupStatusComponentPreview < ViewComponent::Preview
  # @!group Misc

  # @label Not registered yet
  def unregistered
    render SetupStatus::Component.new(
             registration_status: 'unregistered',
             prompt: true,
             admin: false,
           )
  end

  # @label Registration pending
  def pending
    render SetupStatus::Component.new(
             registration_status: 'pending',
             prompt: true,
             admin: false,
           )
  end

  # @label Sponsoring or eligible_for_free
  def sponsoring_or_eligible_for_free
    render SetupStatus::Component.new(
             registration_status: 'complete',
             prompt: false,
             admin: false,
           )
  end

  # @label Registered, but no sponsoring
  def registered_not_sponsoring
    render SetupStatus::Component.new(
             registration_status: 'complete',
             prompt: true,
             admin: false,
           )
  end

  # @label Unknown
  def unknown
    render SetupStatus::Component.new(
             registration_status: 'unknown',
             prompt: true,
             admin: false,
           )
  end

  # @!endgroup
end
