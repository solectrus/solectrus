class Notification::Dot::Component < ViewComponent::Base
  def initialize(unread_count:)
    super()
    @unread_count = unread_count
  end

  attr_reader :unread_count

  def render?
    unread_count.positive?
  end
end
