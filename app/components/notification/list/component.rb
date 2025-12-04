class Notification::List::Component < ViewComponent::Base
  def initialize(notifications:)
    super()
    @notifications = notifications
  end

  attr_reader :notifications
end
