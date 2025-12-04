class Notification::Show::Component < ViewComponent::Base
  def initialize(notification:)
    super()
    @notification = notification
  end

  attr_reader :notification

  delegate :title, :body, :published_at, to: :notification
end
