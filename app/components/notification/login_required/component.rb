# Shown to a guest on the notifications page. Without the login they cannot read
# anything here, and the red mark would stay forever without telling them why.
class Notification::LoginRequired::Component < ViewComponent::Base
  def unread_count
    @unread_count ||= ::Notification.unread_count
  end

  def unread?
    unread_count.positive?
  end

  def login_path
    helpers.new_session_path(return_to: helpers.notifications_path)
  end
end
