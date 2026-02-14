# @label ActionRequired
class ActionRequiredComponentPreview < ViewComponent::Preview
  # @!group Misc

  # @label Not registered yet
  def unregistered
    render ActionRequired::Component.new(
             registration_status: 'unregistered',
             admin: false,
           )
  end

  # @label Registration pending
  def pending
    render ActionRequired::Component.new(
             registration_status: 'pending',
             admin: false,
           )
  end

  # @label Registered, but no sponsoring
  def registered_not_sponsoring
    render ActionRequired::Component.new(
             registration_status: 'complete',
             admin: false,
           )
  end

  # @label Unknown
  def unknown
    render ActionRequired::Component.new(
             registration_status: 'unknown',
             admin: false,
           )
  end

  # @!endgroup
end
