# @label Banner
class BannerComponentPreview < ViewComponent::Preview
  # @!group Non-Admin
  def pending_non_admin
    render Banner::Component.new registration_status: 'pending',
                                 admin: false,
                                 prompt: false
  end

  def unregistered_non_admin
    render Banner::Component.new registration_status: 'unregistered',
                                 prompt: true,
                                 admin: false
  end
  # @!endgroup

  # @!group Admin
  def unregistered_admin
    render Banner::Component.new registration_status: 'unregistered',
                                 prompt: true,
                                 admin: true
  end

  def pending_admin
    render Banner::Component.new registration_status: 'pending',
                                 admin: true,
                                 prompt: false
  end
  # @!endgroup
end
