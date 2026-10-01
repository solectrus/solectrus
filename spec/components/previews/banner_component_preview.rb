# @label Banner
# @display max_width 100%
class BannerComponentPreview < ViewComponent::Preview
  # @!group Overview
  def pending_non_admin
    render Banner::Component.new registration_status: 'pending', admin: false
  end

  def unregistered_non_admin
    render Banner::Component.new registration_status: 'unregistered',
                                 admin: false
  end

  def unregistered_admin
    render Banner::Component.new registration_status: 'unregistered',
                                 admin: true
  end

  def pending_admin
    render Banner::Component.new registration_status: 'pending', admin: true
  end
  # @!endgroup
end
