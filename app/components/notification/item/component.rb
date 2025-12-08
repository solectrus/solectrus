class Notification::Item::Component < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(notification:)
    super()
    @notification = notification
  end

  attr_reader :notification

  delegate :title, :body, :formatted_published_at, :unread?, to: :notification

  def indicator_class
    unread? ? 'bg-red-500' : 'bg-transparent'
  end

  def text_class
    unread? ? 'font-semibold' : nil
  end
end
