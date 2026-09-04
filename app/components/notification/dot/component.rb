class Notification::Dot::Component < ViewComponent::Base
  def render?
    ::Notification.stats.last.positive?
  end
end
