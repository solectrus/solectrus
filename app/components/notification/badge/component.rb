class Notification::Badge::Component < ViewComponent::Base
  def initialize(id:)
    super()
    @id = id
  end

  attr_reader :id

  def unread_count
    @unread_count ||= stats.last
  end

  def link_path
    if unread_count == 1
      helpers.latest_notifications_path
    else
      helpers.notifications_path
    end
  end

  def link_data
    if unread_count == 1
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

  private

  def stats
    @stats ||= ::Notification.stats
  end
end
