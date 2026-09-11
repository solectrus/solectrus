class Notification::Dot::Component < ViewComponent::Base
  def render?
    ::Notification.unread_count.positive?
  end
end
