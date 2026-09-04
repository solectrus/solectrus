class Notification::Item::Component < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(notification:)
    super()
    @notification = notification
  end

  attr_reader :notification

  delegate :title, :formatted_published_at, :unread?, to: :notification
end
