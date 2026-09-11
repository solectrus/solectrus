class Notification::Badge::Component < ViewComponent::Base
  delegate :admin?, to: :helpers

  def unread_count
    @unread_count ||= ::Notification.unread_count
  end

  # Guests see the badge too: on a publicly reachable instance it is the only
  # hint that something is waiting, and the admin often browses from a device
  # where they are not signed in. They go to the list, which explains that
  # reading needs the login. Only an admin goes straight into the message.
  def opens_message?
    admin? && unread_count == 1
  end

  def link_path
    if opens_message?
      helpers.latest_notifications_path
    else
      helpers.notifications_path
    end
  end

  def link_data
    if opens_message?
      { turbo_frame: 'modal', controller: 'tooltip modal-launcher' }
    else
      { turbo_frame: '_top', controller: 'tooltip' }
    end
  end

  def link_title
    t('.news')
  end

  def render?
    unread_count.positive?
  end
end
