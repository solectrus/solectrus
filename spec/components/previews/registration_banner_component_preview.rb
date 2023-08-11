# @label RegistrationBanner
class RegistrationBannerComponentPreview < ViewComponent::Preview
  # @!group Unregistered
  def unregistered_admin
    render RegistrationBanner::Component.new registration_status:
                                               'unregistered',
                                             admin: true
  end

  def unregistered_non_admin
    render RegistrationBanner::Component.new registration_status:
                                               'unregistered',
                                             admin: false
  end
  # @!endgroup

  # @!group Pending
  def pending_admin
    render RegistrationBanner::Component.new registration_status: 'pending',
                                             admin: true
  end

  def pending_non_admin
    render RegistrationBanner::Component.new registration_status: 'pending',
                                             admin: false
  end
  # @!endgroup
end
